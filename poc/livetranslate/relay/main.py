"""Gemini 3.5 Live Translate 릴레이 서버.

중국 본토에서는 만리방화벽(GFW)으로 구글 도메인
(generativelanguage.googleapis.com)이 차단된다. 따라서 클라이언트(폰)는
구글에 직접 붙지 못한다.

이 릴레이는 **중국 밖(예: 도쿄/싱가포르 VPS)** 에서 동작하며:

    [중국 내 Flutter 앱] --(내 WebSocket)--> [이 릴레이] --(Gemini Live API)--> [Google]

- 클라이언트는 구글이 아니라 *이 서버* 에만 연결한다.
- Gemini API 키는 이 서버에만 보관되어 폰에 노출되지 않는다.
- 오디오를 양방향(업/다운)으로 그대로 흘려보낸다.

프로토콜(클라이언트 <-> 릴레이):
- **바이너리 프레임** = 원시 오디오.
    - 업스트림(클라이언트→릴레이): PCM16, 16kHz, mono, little-endian.
    - 다운스트림(릴레이→클라이언트): PCM16, 24kHz, mono (Gemini 출력 그대로).
- **텍스트 프레임(JSON)** = 제어/상태/자막.
    - 다운스트림 예: {"type": "status", "value": "ready"}
                     {"type": "transcript", "text": "..."}
"""
from __future__ import annotations

import asyncio
import base64
import json
import logging
import os
import time
import urllib.error
import urllib.request

import websockets
from dotenv import load_dotenv
from fastapi import Body, FastAPI, HTTPException, Query, Response, WebSocket, WebSocketDisconnect
from websockets.exceptions import ConnectionClosed

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("relay")

# --- 설정 (환경변수) ---------------------------------------------------------
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
# Live Translate 전용 미리보기 모델. 미사용 가능 시 호환 모델로 교체.
GEMINI_LIVE_MODEL = os.environ.get(
    "GEMINI_LIVE_MODEL", "gemini-3.5-live-translate-preview"
)
# 오픈 프록시 악용 방지를 위한 단순 공유 토큰. 빈 값이면 검사 안 함(개발용).
RELAY_TOKEN = os.environ.get("RELAY_TOKEN", "")

GOOGLE_WS_URL = (
    "wss://generativelanguage.googleapis.com/ws/"
    "google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
    "?key={key}"
)

# REST(텍스트/비전/TTS)용 모델. 필요 시 환경변수로 교체.
GEMINI_REST_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
)
GEMINI_TEXT_MODEL = os.environ.get("GEMINI_TEXT_MODEL", "gemini-2.5-flash")
GEMINI_TTS_MODEL = os.environ.get("GEMINI_TTS_MODEL", "gemini-2.5-flash-preview-tts")

# 언어코드 → 영어 이름(번역 지시문에 사용).
LANG_NAMES = {
    "ko": "Korean",
    "zh-CN": "Simplified Chinese",
    "zh-TW": "Traditional Chinese",
    "en": "English",
    "ja": "Japanese",
}

app = FastAPI(title="Gemini Live Translate Relay")


def _require_token(token: str) -> None:
    """REST 엔드포인트 토큰 검사(WS와 동일 정책)."""
    if RELAY_TOKEN and token != RELAY_TOKEN:
        raise HTTPException(status_code=401, detail="unauthorized")
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=503, detail="server_misconfigured")


def _check_token_only(token: str) -> None:
    """Gemini 키가 필요 없는 엔드포인트(환율 등)용 토큰 검사."""
    if RELAY_TOKEN and token != RELAY_TOKEN:
        raise HTTPException(status_code=401, detail="unauthorized")


def _gemini_generate(model: str, body: dict) -> dict:
    """generativelanguage REST generateContent 호출(동기). 키는 서버 보관."""
    url = GEMINI_REST_URL.format(model=model, key=GEMINI_API_KEY)
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)


def _first_text(resp: dict) -> str:
    try:
        return resp["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError, TypeError):
        fr = (resp.get("candidates") or [{}])[0].get("finishReason")
        raise HTTPException(status_code=502, detail=f"no text (finishReason={fr})")


def _first_audio(resp: dict) -> bytes:
    try:
        parts = resp["candidates"][0]["content"]["parts"]
    except (KeyError, IndexError, TypeError):
        fr = (resp.get("candidates") or [{}])[0].get("finishReason")
        raise HTTPException(status_code=502, detail=f"no audio (finishReason={fr})")
    for p in parts:
        inline = p.get("inlineData")
        if inline and inline.get("data"):
            return base64.b64decode(inline["data"])
    # 오디오가 없고 텍스트만 온 경우(모델이 읽지 않고 답하려 함).
    txt = next((p.get("text", "") for p in parts if p.get("text")), "")
    raise HTTPException(status_code=502, detail=f"TTS returned no audio: {txt[:120]}")


def _tts_pcm(text: str) -> bytes:
    """텍스트 → 24kHz PCM16 음성(Gemini TTS).

    TTS 모델이 입력을 '질문'으로 보고 답하려 하지 않도록, 그대로 읽으라는
    스타일 지시를 앞에 붙인다(지시 부분은 음성으로 읽히지 않음).
    """
    resp = _gemini_generate(
        GEMINI_TTS_MODEL,
        {
            "contents": [
                {"parts": [{"text": f"Say in a natural, friendly voice: {text}"}]}
            ],
            "generationConfig": {
                "responseModalities": ["AUDIO"],
                "speechConfig": {
                    "voiceConfig": {"prebuiltVoiceConfig": {"voiceName": "Kore"}}
                },
            },
        },
    )
    return _first_audio(resp)


@app.get("/health")
async def health() -> dict:
    """헬스체크. 키 설정 여부만 노출(키 값 자체는 비노출)."""
    return {"status": "ok", "model": GEMINI_LIVE_MODEL, "key_configured": bool(GEMINI_API_KEY)}


@app.post("/speak")
def speak(payload: dict = Body(...), token: str = Query("")) -> dict:
    """문구 텍스트를 대상 언어로 번역 + 음성 합성.

    body: {"text": "화장실 어디예요?", "targetLang": "zh-CN"}
    반환: {"translated": "...", "audio": "<base64 PCM16 24kHz>"}
    """
    _require_token(token)
    text = (payload.get("text") or "").strip()
    target = payload.get("targetLang", "en")
    if not text:
        raise HTTPException(status_code=400, detail="empty text")
    tname = LANG_NAMES.get(target, target)
    try:
        tr = _gemini_generate(
            GEMINI_TEXT_MODEL,
            {
                "contents": [
                    {
                        "parts": [
                            {
                                "text": "Translate the following into "
                                f"{tname}. Output only the translation, no "
                                f"quotes or notes:\n{text}"
                            }
                        ]
                    }
                ]
            },
        )
        translated = _first_text(tr)
        pcm = _tts_pcm(translated)
    except HTTPException:
        raise
    except urllib.error.HTTPError as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=exc.read().decode()[:200])
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"{type(exc).__name__}: {exc}")
    return {"translated": translated, "audio": base64.b64encode(pcm).decode("ascii")}


@app.post("/ocr")
def ocr(payload: dict = Body(...), token: str = Query("")) -> dict:
    """이미지 속 텍스트 인식 + 대상 언어 번역.

    body: {"image": "<base64 jpeg>", "targetLang": "ko"}
    반환: {"original": "...", "translated": "..."}
    """
    _require_token(token)
    image = payload.get("image")
    target = payload.get("targetLang", "ko")
    if not image:
        raise HTTPException(status_code=400, detail="no image")
    tname = LANG_NAMES.get(target, target)
    try:
        resp = _gemini_generate(
            GEMINI_TEXT_MODEL,
            {
                "contents": [
                    {
                        "parts": [
                            {
                                "text": "Read all text in this image. Then "
                                f"translate it into {tname}. Respond ONLY as "
                                'JSON {"original":"...","translated":"..."}.'
                            },
                            {"inlineData": {"mimeType": "image/jpeg", "data": image}},
                        ]
                    }
                ],
                "generationConfig": {"responseMimeType": "application/json"},
            },
        )
        parsed = json.loads(_first_text(resp))
    except HTTPException:
        raise
    except urllib.error.HTTPError as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=exc.read().decode()[:200])
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"{type(exc).__name__}: {exc}")
    return {
        "original": parsed.get("original", ""),
        "translated": parsed.get("translated", ""),
    }


# 환율 캐시(base 통화별 rates, 1시간 TTL).
_rate_cache: dict[str, tuple[float, dict]] = {}


@app.get("/rate")
def rate(
    base: str = Query("CNY"), quote: str = Query("KRW"), token: str = Query("")
) -> dict:
    """환율 조회. 1차: open.er-api.com(전체표·1h캐시), 2차: frankfurter(쌍)."""
    _check_token_only(token)
    base = base.upper()
    quote = quote.upper()
    now = time.time()

    # 1차: open.er-api.com (base별 전체 환율표 캐시)
    try:
        cached = _rate_cache.get(base)
        if not cached or now - cached[0] > 3600:
            with urllib.request.urlopen(
                f"https://open.er-api.com/v6/latest/{base}", timeout=30
            ) as r:
                data = json.load(r)
            if data.get("result") == "success" and "rates" in data:
                _rate_cache[base] = (now, data["rates"])
                cached = _rate_cache[base]
            else:
                cached = None
        if cached and quote in cached[1]:
            return {
                "base": base,
                "quote": quote,
                "rate": cached[1][quote],
                "ts": int(cached[0]),
            }
    except Exception:  # noqa: BLE001 - 폴백으로 넘어간다.
        pass

    # 2차: frankfurter.app (단일 쌍)
    try:
        with urllib.request.urlopen(
            f"https://api.frankfurter.app/latest?from={base}&to={quote}", timeout=30
        ) as r:
            data = json.load(r)
        value = data["rates"][quote]
        return {"base": base, "quote": quote, "rate": value, "ts": int(now)}
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"rate fetch failed: {exc}")


@app.post("/bargain")
def bargain(payload: dict = Body(...), token: str = Query("")) -> dict:
    """흥정 도우미: 제안 가격 → 대상 언어로 자연스러운 흥정 문장 + 음성.

    body: {"amount": 200, "currency": "CNY", "targetLang": "zh-CN"}
    반환: {"text": "...", "audio": "<base64 PCM16 24kHz>"}
    """
    _require_token(token)
    amount = payload.get("amount")
    currency = payload.get("currency", "")
    target = payload.get("targetLang", "zh-CN")
    if amount is None or f"{amount}".strip() == "":
        raise HTTPException(status_code=400, detail="no amount")
    tname = LANG_NAMES.get(target, target)
    prompt = (
        "You are helping a tourist bargain politely at a market. Write ONE "
        f"short, friendly and polite sentence in {tname} asking the seller to "
        f"lower the price to {amount} {currency}. Natural, warm tone. Output "
        "only the sentence, no quotes or notes."
    )
    try:
        tr = _gemini_generate(
            GEMINI_TEXT_MODEL, {"contents": [{"parts": [{"text": prompt}]}]}
        )
        text = _first_text(tr)
        pcm = _tts_pcm(text)
    except HTTPException:
        raise
    except urllib.error.HTTPError as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=exc.read().decode()[:200])
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"{type(exc).__name__}: {exc}")
    return {"text": text, "audio": base64.b64encode(pcm).decode("ascii")}


def _build_setup(target: str) -> dict:
    """Gemini Live API 초기 setup 메시지를 만든다.

    target: 번역 대상 언어코드 (예: "zh-CN", "ko", "en").

    입력 언어는 모델이 자동 감지한다. (API가 translationConfig에
    sourceLanguageCode 필드를 받지 않음 — 실측 확인.)
    """
    translation_config = {
        "targetLanguageCode": target,
    }
    return {
        "setup": {
            "model": f"models/{GEMINI_LIVE_MODEL}",
            "generationConfig": {
                "responseModalities": ["AUDIO"],
                "translationConfig": translation_config,
            },
            # 자동 VAD를 끄고 클라이언트가 발화 시작/끝을 명시(푸시투토크).
            # 손 떼는 즉시 activityEnd로 확정 → 지연 최소화.
            "realtimeInputConfig": {
                "automaticActivityDetection": {"disabled": True}
            },
        }
    }


async def _pump_client_to_google(client_ws: WebSocket, google_ws) -> None:
    """클라이언트 → 구글: 마이크 오디오를 realtimeInput으로 전달."""
    while True:
        msg = await client_ws.receive()
        if msg["type"] == "websocket.disconnect":
            raise WebSocketDisconnect()

        data = msg.get("bytes")
        if data is not None:
            # 원시 PCM16/16kHz 청크를 base64로 감싸 전송.
            payload = {
                "realtimeInput": {
                    "mediaChunks": [
                        {
                            "mimeType": "audio/pcm;rate=16000",
                            "data": base64.b64encode(data).decode("ascii"),
                        }
                    ]
                }
            }
            await google_ws.send(json.dumps(payload))
            continue

        # 텍스트(JSON) 제어 메시지.
        text = msg.get("text")
        if text:
            try:
                control = json.loads(text)
            except json.JSONDecodeError:
                continue
            # 하트비트: GFW가 조용히 끊는 경우를 클라이언트가 감지하도록 즉시 응답.
            if control.get("type") == "ping":
                await client_ws.send_text(json.dumps({"type": "pong"}))
            elif control.get("type") == "start":
                # 푸시투토크 누름 → 발화 시작(수동 VAD).
                await google_ws.send(
                    json.dumps({"realtimeInput": {"activityStart": {}}})
                )
            elif control.get("type") == "end":
                # 푸시투토크 손 뗌 → 발화 끝 → 즉시 번역 확정.
                await google_ws.send(
                    json.dumps({"realtimeInput": {"activityEnd": {}}})
                )


async def _pump_google_to_client(client_ws: WebSocket, google_ws) -> None:
    """구글 → 클라이언트: 번역된 오디오/자막을 내려보낸다."""
    async for raw in google_ws:
        event = json.loads(raw)

        server_content = event.get("serverContent")
        if not server_content:
            # setupComplete 등 제어 이벤트.
            if "setupComplete" in event:
                await client_ws.send_text(json.dumps({"type": "status", "value": "ready"}))
            continue

        model_turn = server_content.get("modelTurn", {})
        for part in model_turn.get("parts", []):
            inline = part.get("inlineData")
            if inline and inline.get("data"):
                audio = base64.b64decode(inline["data"])
                await client_ws.send_bytes(audio)  # PCM16/24kHz
            text = part.get("text")
            if text:
                await client_ws.send_text(json.dumps({"type": "transcript", "text": text}))

        if server_content.get("turnComplete"):
            await client_ws.send_text(json.dumps({"type": "status", "value": "turn_complete"}))


@app.websocket("/ws/translate")
async def translate(
    client_ws: WebSocket,
    target: str = Query("zh-CN", description="번역 대상 언어코드"),
    token: str = Query("", description="릴레이 접근 토큰"),
) -> None:
    await client_ws.accept()

    if RELAY_TOKEN and token != RELAY_TOKEN:
        await client_ws.send_text(json.dumps({"type": "error", "value": "unauthorized"}))
        await client_ws.close(code=4401)
        return

    if not GEMINI_API_KEY:
        await client_ws.send_text(json.dumps({"type": "error", "value": "server_misconfigured"}))
        await client_ws.close(code=1011)
        return

    url = GOOGLE_WS_URL.format(key=GEMINI_API_KEY)
    log.info("client connected (target=%s)", target)

    try:
        # 업스트림 keepalive: 죽은 연결을 빨리 감지해 끊는다(클라이언트가 재연결).
        async with websockets.connect(
            url,
            max_size=None,
            ping_interval=20,
            ping_timeout=20,
            close_timeout=5,
        ) as google_ws:
            # 1) setup 전송 후 setupComplete 대기.
            await google_ws.send(json.dumps(_build_setup(target)))

            # 2) 양방향 펌프 동시 실행. 한쪽이 끝나면 전체 종료.
            await asyncio.gather(
                _pump_client_to_google(client_ws, google_ws),
                _pump_google_to_client(client_ws, google_ws),
            )
    except WebSocketDisconnect:
        log.info("client disconnected")
    except ConnectionClosed as exc:
        log.warning("google connection closed: %s", exc)
        await _safe_close(client_ws, 1011, "upstream_closed")
    except Exception as exc:  # noqa: BLE001 - 릴레이는 어떤 오류든 클라이언트에 알리고 닫는다.
        log.exception("relay error: %s", exc)
        await _safe_close(client_ws, 1011, "relay_error")


async def _safe_close(ws: WebSocket, code: int, reason: str) -> None:
    """이미 닫혔을 수 있는 소켓을 안전하게 닫는다."""
    try:
        await ws.send_text(json.dumps({"type": "error", "value": reason}))
        await ws.close(code=code)
    except Exception:  # noqa: BLE001
        pass


if __name__ == "__main__":
    import uvicorn

    # 클라우드 플랫폼(Render/Fly/Railway 등)은 PORT를 주입한다. 그걸 우선 사용.
    port = int(os.environ.get("PORT") or os.environ.get("RELAY_PORT") or "8080")
    uvicorn.run(
        "main:app",
        host=os.environ.get("RELAY_HOST", "0.0.0.0"),
        port=port,
        reload=bool(os.environ.get("RELAY_RELOAD")),
    )
