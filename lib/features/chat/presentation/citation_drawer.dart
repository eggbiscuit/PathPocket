import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/message.dart';

/// State for the citation drawer/sheet.
///
/// Phase 1 wires up the protocol end-to-end but only logs taps; Phase 2
/// turns this provider's state into an actual drawer that slides up/in.
class CitationFocus {
  const CitationFocus({required this.messageId, required this.citationId});
  final String messageId;
  final String citationId;
}

class CitationDrawerState {
  const CitationDrawerState({
    this.open = false,
    this.citations = const [],
    this.focus,
  });

  final bool open;
  final List<Citation> citations;
  final CitationFocus? focus;

  CitationDrawerState copyWith({
    bool? open,
    List<Citation>? citations,
    CitationFocus? focus,
    bool clearFocus = false,
  }) {
    return CitationDrawerState(
      open: open ?? this.open,
      citations: citations ?? this.citations,
      focus: clearFocus ? null : (focus ?? this.focus),
    );
  }
}

class CitationDrawerNotifier extends Notifier<CitationDrawerState> {
  @override
  CitationDrawerState build() => const CitationDrawerState();

  void openFor({
    required String messageId,
    required List<Citation> citations,
    required String citationId,
  }) {
    state = CitationDrawerState(
      open: true,
      citations: citations,
      focus: CitationFocus(messageId: messageId, citationId: citationId),
    );
  }

  void close() {
    state = state.copyWith(open: false, clearFocus: true);
  }
}

final citationDrawerProvider =
    NotifierProvider<CitationDrawerNotifier, CitationDrawerState>(
  CitationDrawerNotifier.new,
);
