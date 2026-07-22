"""Task #42 verification — dashscope Recognition callback threading model.

Run from backend/:  .venv/bin/python scripts/asr_demo.py [path-to-16k-pcm]

Confirms:
  1. Which thread the SDK invokes on_event/on_error/on_complete on (is it the
     main thread, or an SDK-owned receive thread?). This decides whether
     asr_bridge's `loop.call_soon_threadsafe` hop is actually required.
  2. That start()/send_audio_frame()/stop() behave as the bridge assumes.

If no PCM file is given, generates 2s of silence so the connection + callback
wiring can be exercised even without real speech (expect empty/near-empty
transcripts — the point is to observe threading, not accuracy).
"""

import os
import sys
import threading
import time

import dashscope
from dashscope.audio.asr import Recognition, RecognitionCallback, RecognitionResult

MAIN_THREAD = threading.get_ident()


def _tag() -> str:
    tid = threading.get_ident()
    where = "MAIN" if tid == MAIN_THREAD else "SDK-THREAD"
    return f"[{where} tid={tid} name={threading.current_thread().name}]"


class DemoCallback(RecognitionCallback):
    def on_open(self) -> None:
        print(f"{_tag()} on_open")

    def on_event(self, result: RecognitionResult) -> None:
        sentence = result.get_sentence()
        text = sentence.get("text", "") if sentence else ""
        end = RecognitionResult.is_sentence_end(sentence) if sentence else False
        print(f"{_tag()} on_event end={end} text={text!r}")

    def on_error(self, result: RecognitionResult) -> None:
        print(f"{_tag()} on_error {getattr(result, 'message', result)}")

    def on_complete(self) -> None:
        print(f"{_tag()} on_complete")

    def on_close(self) -> None:
        print(f"{_tag()} on_close")


def main() -> None:
    key = os.environ.get("DASHSCOPE_API_KEY")
    if not key:
        # Fall back to backend/.env so `.venv/bin/python scripts/asr_demo.py` works.
        from app.config import get_settings

        key = get_settings().dashscope_api_key
    if not key:
        print("DASHSCOPE_API_KEY 未设置 — 无法连真实服务。仅打印 MAIN tid 后退出。")
        print(f"{_tag()} main")
        return
    dashscope.api_key = key

    if len(sys.argv) > 1:
        with open(sys.argv[1], "rb") as f:
            audio = f.read()
        print(f"loaded {len(audio)} bytes PCM from {sys.argv[1]}")
    else:
        audio = b"\x00\x00" * 16000 * 2  # 2s silence @ 16kHz PCM16
        print("no PCM file given — using 2s silence")

    print(f"{_tag()} main (before start)")
    rec = Recognition(
        model="paraformer-realtime-v2",
        format="pcm",
        sample_rate=16000,
        callback=DemoCallback(),
    )
    rec.start()
    print(f"{_tag()} after start()")

    # Feed in ~100ms frames, mimicking a live mic.
    frame = 3200  # 100ms @ 16kHz PCM16
    for i in range(0, len(audio), frame):
        rec.send_audio_frame(audio[i : i + frame])
        time.sleep(0.1)
    rec.stop()
    print(f"{_tag()} after stop()")
    time.sleep(0.5)


if __name__ == "__main__":
    main()
