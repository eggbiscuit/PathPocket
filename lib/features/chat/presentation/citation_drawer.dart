import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
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

// ── Citation drawer host ──────────────────────────────────────────────────────

class CitationDrawerHost extends ConsumerWidget {
  const CitationDrawerHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerState = ref.watch(citationDrawerProvider);
    if (!drawerState.open) return child;

    final isWide = MediaQuery.sizeOf(context).width >= 900;
    if (isWide) {
      return Row(
        children: [
          Expanded(child: child),
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          SizedBox(
            width: 320,
            child: _CitationPanel(
              citations: drawerState.citations,
              focusId: drawerState.focus?.citationId,
              onClose: () =>
                  ref.read(citationDrawerProvider.notifier).close(),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        child,
        DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (_, ctrl) => _CitationPanel(
            citations: drawerState.citations,
            focusId: drawerState.focus?.citationId,
            scrollController: ctrl,
            onClose: () =>
                ref.read(citationDrawerProvider.notifier).close(),
          ),
        ),
      ],
    );
  }
}

class _CitationPanel extends StatelessWidget {
  const _CitationPanel({
    required this.citations,
    required this.focusId,
    required this.onClose,
    this.scrollController,
  });

  final List<Citation> citations;
  final String? focusId;
  final VoidCallback onClose;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accentColor = p.accent;

    return Material(
      color: p.bgSurface,
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '参考文献',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: p.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: p.textTertiary,
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: p.divider,
          ),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: citations.length,
              separatorBuilder: (_, __) => Divider(
                height: 16,
                color: p.divider,
              ),
              itemBuilder: (_, i) {
                final c = citations[i];
                final isFocused = c.id == focusId;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? p.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: isFocused
                        ? Border.all(
                            color: p.primary,
                            width: 1,
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.title,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.snippet,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          height: 1.5,
                          color: p.textSecondary,
                        ),
                      ),
                      if (c.source != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            c.source!,
                            style: AppTextStyles.tiny(context),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
