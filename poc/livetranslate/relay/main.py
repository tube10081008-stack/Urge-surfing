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

import websockets
from dotenv import load_dotenv
from fastapi import FastAPI, Query, WebSocket, WebSocketDisconnect
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

app = FastAPI(title="Gemini Live Translate Relay")


@app.get("/health")
async def health() -> dict:
    """헬스체크. 키 설정 여부만 노출(키 값 자체는 비노출)."""
    return {"status": "ok", "model": GEMINI_LIVE_MODEL, "key_configured": bool(GEMINI_API_KEY)}


def _build_setup(target: str) -> dict:
    """Gemini Live API 초기 setup 메시지를 만든다.

    target: 번역 대상 언어코드 (예: "zh-CN", "ko", "en").

    입력 언어는 모델이 자동 감지한다. (API가 translationConfig에
    sourceLanguageCode 필드를 받지 않음 — 실측 확인.)
    """
    translation_config = {
        "targetLanguageCode": target,
        # 대상 언어를 음성으로 그대로 들려준다.
        "echoTargetLanguage": True,
    }
    return {
        "setup": {
            "model": f"models/{GEMINI_LIVE_MODEL}",
            "generationConfig": {
                "responseModalities": ["AUDIO"],
                "translationConfig": translation_config,
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
