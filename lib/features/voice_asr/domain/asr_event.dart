/// Transcript events streamed back from the backend /asr/stream endpoint.
sealed class AsrEvent {
  const AsrEvent();
}

/// Interim (not yet finalized) transcript — overwrites the live preview.
class PartialAsrEvent extends AsrEvent {
  const PartialAsrEvent(this.text);
  final String text;
}

/// A finalized sentence — should be committed to the input.
class FinalAsrEvent extends AsrEvent {
  const FinalAsrEvent(this.text);
  final String text;
}

/// Recognition failed or the connection dropped.
class AsrErrorEvent extends AsrEvent {
  const AsrErrorEvent(this.message);
  final String message;
}
