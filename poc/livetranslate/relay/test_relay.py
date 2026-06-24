"""릴레이 중계 로직 테스트.

실제 Gemini API 키 없이, 구글 업스트림 WebSocket을 모킹하여
릴레이가 오디오를 양방향으로 올바르게 중계하는지 검증한다.

검증 항목:
- setup 메시지가 올바른 모델/번역설정으로 구글에 전달되는가
- 클라이언트가 보낸 오디오(바이너리)가 realtimeInput으로 변환되는가
- 구글의 serverContent 오디오가 클라이언트에 바이너리로 전달되는가
- setupComplete → status:ready 가 클라이언트에 전달되는가
"""
import asyncio
import base64
import json

import main
import pytest
from fastapi.testclient import TestClient


class FakeGoogleWS:
    """구글 Live API WebSocket 흉내. send를 받으면 적절한 응답을 큐에 넣는다.

    asyncio.Queue를 써서 send(put)가 __anext__(get)을 깨우도록 한다.
    """

    def __init__(self):
        self.sent: list[dict] = []
        self._queue: asyncio.Queue[str] = asyncio.Queue()

    async def send(self, data: str) -> None:
        msg = json.loads(data)
        self.sent.append(msg)
        if "setup" in msg:
            await self._queue.put(json.dumps({"setupComplete": {}}))
        if "realtimeInput" in msg:
            # 받은 오디오에 대응해 번역 오디오 한 청크를 돌려준다.
            audio = base64.b64encode(b"TRANSLATED").decode("ascii")
            await self._queue.put(
                json.dumps(
                    {
                        "serverContent": {
                            "modelTurn": {
                                "parts": [
                                    {
                                        "inlineData": {
                                            "mimeType": "audio/pcm;rate=24000",
                                            "data": audio,
                                        }
                                    }
                                ]
                            }
                        }
                    }
                )
            )

    def __aiter__(self):
        return self

    async def __anext__(self) -> str:
        # 큐에 들어올 때까지 대기. 클라이언트 종료 시 gather가 이 태스크를 취소.
        return await self._queue.get()


class _FakeConnect:
    def __init__(self, ws):
        self._ws = ws

    async def __aenter__(self):
        return self._ws

    async def __aexit__(self, *exc):
        return False


@pytest.fixture
def client(monkeypatch):
    fake = FakeGoogleWS()
    monkeypatch.setattr(main, "GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(main, "RELAY_TOKEN", "")
    monkeypatch.setattr(main.websockets, "connect", lambda url, **kw: _FakeConnect(fake))
    test_client = TestClient(main.app)
    test_client.fake_google = fake  # 검증용 핸들
    return test_client


def test_relay_pumps_audio_both_ways(client):
    with client.websocket_connect("/ws/translate?target=zh-CN") as ws:
        # setupComplete → status:ready
        ready = json.loads(ws.receive_text())
        assert ready == {"type": "status", "value": "ready"}

        # 클라이언트 → 릴레이 → 구글: 오디오 송신
        ws.send_bytes(b"\x10\x20\x30\x40")

        # 구글 → 릴레이 → 클라이언트: 번역 오디오 수신
        out = ws.receive_bytes()
        assert out == b"TRANSLATED"

    # 구글에 전달된 메시지 검증
    sent = client.fake_google.sent
    setup = sent[0]["setup"]
    assert setup["model"] == "models/gemini-3.5-live-translate-preview"
    cfg = setup["generationConfig"]
    assert cfg["responseModalities"] == ["AUDIO"]
    assert cfg["translationConfig"]["targetLanguageCode"] == "zh-CN"

    realtime = sent[1]["realtimeInput"]["mediaChunks"][0]
    assert realtime["mimeType"] == "audio/pcm;rate=16000"
    assert base64.b64decode(realtime["data"]) == b"\x10\x20\x30\x40"


def test_ping_pong(client):
    """클라이언트 하트비트(ping)에 릴레이가 즉시 pong으로 응답한다."""
    with client.websocket_connect("/ws/translate?target=zh-CN") as ws:
        assert json.loads(ws.receive_text())["value"] == "ready"
        ws.send_text(json.dumps({"type": "ping"}))
        assert json.loads(ws.receive_text()) == {"type": "pong"}


def test_rejects_bad_token(monkeypatch):
    monkeypatch.setattr(main, "GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(main, "RELAY_TOKEN", "secret")
    c = TestClient(main.app)
    with c.websocket_connect("/ws/translate?target=zh-CN&token=wrong") as ws:
        msg = json.loads(ws.receive_text())
        assert msg == {"type": "error", "value": "unauthorized"}


def test_speak_requires_text(client):
    r = client.post("/speak", json={"text": "", "targetLang": "zh-CN"})
    assert r.status_code == 400


def test_ocr_requires_image(client):
    r = client.post("/ocr", json={"targetLang": "ko"})
    assert r.status_code == 400


def test_speak_bad_token(monkeypatch):
    monkeypatch.setattr(main, "GEMINI_API_KEY", "k")
    monkeypatch.setattr(main, "RELAY_TOKEN", "secret")
    c = TestClient(main.app)
    r = c.post("/speak?token=wrong", json={"text": "hi", "targetLang": "en"})
    assert r.status_code == 401


def test_rate_bad_token(monkeypatch):
    monkeypatch.setattr(main, "RELAY_TOKEN", "secret")
    c = TestClient(main.app)
    assert c.get("/rate?base=CNY&quote=KRW&token=wrong").status_code == 401


def test_bargain_bad_token(monkeypatch):
    monkeypatch.setattr(main, "GEMINI_API_KEY", "k")
    monkeypatch.setattr(main, "RELAY_TOKEN", "secret")
    c = TestClient(main.app)
    assert c.post("/bargain?token=wrong", json={"amount": 200}).status_code == 401


def test_health(monkeypatch):
    monkeypatch.setattr(main, "GEMINI_API_KEY", "")
    c = TestClient(main.app)
    r = c.get("/health")
    assert r.status_code == 200
    assert r.json()["key_configured"] is False
