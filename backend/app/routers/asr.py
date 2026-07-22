"""Streaming speech-to-text over WebSocket.

The client opens ws://.../asr/stream?token=<access_token>, sends raw 16 kHz
PCM16 audio frames as binary messages, and receives JSON transcript events
({"type": "partial"/"final"/"error", ...}). Sending the text frame "__stop__"
(or disconnecting) ends the session.

WebSocket routes can't use `Depends(oauth2_scheme)` — Starlette doesn't run the
header-based security scheme on the handshake — so we pull the token from the
query string and validate it manually. This is the repo's first WS endpoint;
the query-param auth pattern is established here.
"""

import asyncio
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jose import JWTError
from starlette.concurrency import run_in_threadpool

from .. import security
from ..asr_bridge import AsrSession

logger = logging.getLogger("pathpocket")

router = APIRouter(prefix="/asr", tags=["asr"])

_STOP = "__stop__"


@router.websocket("/stream")
async def stream(websocket: WebSocket) -> None:
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        return
    try:
        security.decode_token(token, security.ACCESS)
    except Exception:
        # decode_token raises HTTPException (401) on bad/expired tokens; any
        # failure here means the handshake is unauthenticated.
        await websocket.close(code=4401)
        return

    await websocket.accept()

    loop = asyncio.get_running_loop()
    session = AsrSession(loop)
    try:
        await run_in_threadpool(session.start)
    except Exception as exc:  # dashscope key missing / connect failure
        logger.warning("ASR session start failed: %s", exc)
        await websocket.send_json({"type": "error", "message": "语音识别服务不可用"})
        await websocket.close(code=1011)
        return

    async def pump_events() -> None:
        try:
            async for event in session.events():
                await websocket.send_json(event)
        except (WebSocketDisconnect, RuntimeError):
            pass

    events_task = asyncio.create_task(pump_events())
    try:
        while True:
            message = await websocket.receive()
            if message.get("type") == "websocket.disconnect":
                break
            if (text := message.get("text")) is not None:
                if text == _STOP:
                    break
                continue
            if (data := message.get("bytes")) is not None:
                await run_in_threadpool(session.send_audio_frame, data)
    except WebSocketDisconnect:
        pass
    finally:
        await run_in_threadpool(session.stop)
        await events_task
        try:
            await websocket.close()
        except RuntimeError:
            pass
