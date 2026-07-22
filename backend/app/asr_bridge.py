"""Bridges Aliyun DashScope's callback-based ASR into an asyncio world.

The `dashscope` SDK's `Recognition` delivers results through a synchronous
callback invoked on the SDK's own receive thread. FastAPI's WebSocket route
lives on the event loop, so we hop every callback onto the loop via
`loop.call_soon_threadsafe` and hand results to the route through an
`asyncio.Queue`. Blocking SDK calls (`start`/`send_audio_frame`/`stop`) are
meant to be driven from the route with `run_in_threadpool`.
"""

import asyncio
from typing import Any

import dashscope
from dashscope.audio.asr import Recognition, RecognitionCallback, RecognitionResult

from .config import get_settings

_settings = get_settings()


class AsrSession:
    """One live recognition session, tied to a single WebSocket connection.

    Events pushed onto the queue (consumed via `events()`):
        {"type": "partial", "text": str}  — interim transcript
        {"type": "final",   "text": str}  — a finalized sentence
        {"type": "error",   "message": str}
        {"type": "closed"}                — recognition completed/closed
    """

    def __init__(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop
        self._queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
        self._recognition: Recognition | None = None
        self._started = False

    def _emit(self, event: dict[str, Any]) -> None:
        # Runs on the SDK receive thread — hand off to the event-loop thread.
        self._loop.call_soon_threadsafe(self._queue.put_nowait, event)

    def start(self) -> None:
        """Opens the recognition session. Blocking — call via run_in_threadpool."""
        if not _settings.dashscope_api_key:
            raise RuntimeError("DASHSCOPE_API_KEY 未配置")
        dashscope.api_key = _settings.dashscope_api_key
        session = self

        class _Callback(RecognitionCallback):
            def on_event(self, result: RecognitionResult) -> None:
                sentence = result.get_sentence()
                if not sentence:
                    return
                text = sentence.get("text", "")
                if not text:
                    return
                is_end = RecognitionResult.is_sentence_end(sentence)
                session._emit(
                    {"type": "final" if is_end else "partial", "text": text}
                )

            def on_error(self, result: RecognitionResult) -> None:
                message = getattr(result, "message", None) or str(result)
                session._emit({"type": "error", "message": str(message)})

            def on_complete(self) -> None:
                session._emit({"type": "closed"})

        kwargs: dict[str, Any] = {
            "model": _settings.asr_model,
            "format": "pcm",
            "sample_rate": 16000,
            "callback": _Callback(),
        }
        if _settings.asr_vocabulary_id:
            kwargs["vocabulary_id"] = _settings.asr_vocabulary_id

        self._recognition = Recognition(**kwargs)
        self._recognition.start()
        self._started = True

    def send_audio_frame(self, data: bytes) -> None:
        """Forwards one PCM frame. Blocking — call via run_in_threadpool."""
        if self._recognition is not None and self._started:
            self._recognition.send_audio_frame(data)

    def stop(self) -> None:
        """Closes the session. Blocking — call via run_in_threadpool. Idempotent."""
        if self._recognition is not None and self._started:
            self._started = False
            try:
                self._recognition.stop()
            except Exception:
                pass

    async def events(self):
        while True:
            event = await self._queue.get()
            yield event
            if event["type"] == "closed":
                break
