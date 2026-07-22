"""Tests for the /asr/stream WebSocket endpoint.

httpx.AsyncClient (the `client` fixture in conftest) can't do WebSockets, so
these use starlette's synchronous TestClient. Auth-rejection paths run without
touching DashScope; the channel-logic test monkeypatches AsrSession so no real
API call is made. The real end-to-end recognition path needs a live key and is
covered by scripts/asr_demo.py, not here.
"""

import asyncio

import pytest
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app import asr_bridge
from app.main import app
from app.security import create_access_token, create_verify_token


def test_stream_requires_token():
    with TestClient(app) as tc:
        with pytest.raises(WebSocketDisconnect) as exc:
            with tc.websocket_connect("/asr/stream"):
                pass
    assert exc.value.code == 4401


def test_stream_rejects_invalid_token():
    with TestClient(app) as tc:
        with pytest.raises(WebSocketDisconnect) as exc:
            with tc.websocket_connect("/asr/stream?token=not-a-jwt"):
                pass
    assert exc.value.code == 4401


def test_stream_rejects_wrong_token_type():
    # A verify token is a valid JWT but wrong `typ` — must be rejected.
    token = create_verify_token("user-123")
    with TestClient(app) as tc:
        with pytest.raises(WebSocketDisconnect) as exc:
            with tc.websocket_connect(f"/asr/stream?token={token}"):
                pass
    assert exc.value.code == 4401


class _FakeSession:
    """Stand-in for AsrSession: echoes a partial+final per received frame."""

    def __init__(self, loop):
        self._loop = loop
        self._queue: asyncio.Queue = asyncio.Queue()
        self.started = False
        self.stopped = False
        self.frames: list[bytes] = []

    def start(self):
        self.started = True

    def send_audio_frame(self, data: bytes):
        self.frames.append(data)
        self._queue.put_nowait({"type": "partial", "text": "识"})
        self._queue.put_nowait({"type": "final", "text": "识别"})

    def stop(self):
        self.stopped = True
        self._queue.put_nowait({"type": "closed"})

    async def events(self):
        while True:
            event = await self._queue.get()
            yield event
            if event["type"] == "closed":
                break


def test_stream_channel_logic(monkeypatch):
    monkeypatch.setattr("app.routers.asr.AsrSession", _FakeSession)
    token = create_access_token("user-123")
    with TestClient(app) as tc:
        with tc.websocket_connect(f"/asr/stream?token={token}") as ws:
            ws.send_bytes(b"\x00\x00" * 160)
            assert ws.receive_json() == {"type": "partial", "text": "识"}
            assert ws.receive_json() == {"type": "final", "text": "识别"}
            ws.send_text("__stop__")
