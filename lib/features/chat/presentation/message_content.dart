import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme.dart';
import '../domain/message.dart';
import 'chat_provider.dart';

// ── Streaming indicator (dots) ────────────────────────────────────────────────

class StreamingIndicator extends StatefulWidget {
  const StreamingIndicator({super.key});

  @override
  State<StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.palette.primary;
    return Row(
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anim,
          builder: (_, __) {
            final delay = i * 0.33;
            final val = (((_anim.value + delay) % 1.0));
            final opacity = (val < 0.5 ? val * 2 : (1 - val) * 2).clamp(0.3, 1.0);
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

// ── Markdown content with streaming cursor ────────────────────────────────────

class MarkdownContent extends StatefulWidget {
  const MarkdownContent({
    super.key,
    required this.content,
    required this.citations,
    required this.isStreaming,
    required this.onCitationTap,
  });

  final String content;
  final List<Citation> citations;
  final bool isStreaming;
  final void Function(String) onCitationTap;

  @override
  State<MarkdownContent> createState() => _MarkdownContentState();
}

class _MarkdownContentState extends State<MarkdownContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorCtrl;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = p.textPrimary;
    final secondaryColor = p.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: _preprocessCitations(widget.content),
          selectable: true,
          extensionSet: md.ExtensionSet.gitHubFlavored,
          styleSheet: MarkdownStyleSheet(
            p: GoogleFonts.dmSans(
              fontSize: 15, height: 1.65, color: textColor),
            strong: GoogleFonts.dmSans(
              fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
            em: GoogleFonts.dmSans(
              fontSize: 15, fontStyle: FontStyle.italic, color: textColor),
            h1: GoogleFonts.dmSerifDisplay(
              fontSize: 20, color: textColor),
            h2: GoogleFonts.dmSans(
              fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
            h3: GoogleFonts.dmSans(
              fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            code: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              backgroundColor: isDark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF0EDEA),
              color: textColor,
            ),
            a: GoogleFonts.dmSans(
              fontSize: 15,
              color: p.primary,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: p.primary,
                  width: 3,
                ),
              ),
              color: p.primaryContainer,
            ),
            listBullet: GoogleFonts.dmSans(
              fontSize: 15, color: secondaryColor),
          ),
          onTapLink: (text, href, _) {
            if (href != null && href.startsWith('cite://')) {
              widget.onCitationTap(href.substring('cite://'.length));
            }
          },
        ),
        // Streaming cursor ▌
        if (widget.isStreaming)
          AnimatedBuilder(
            animation: _cursorCtrl,
            builder: (_, __) => Opacity(
              opacity: _cursorCtrl.value,
              child: Text(
                '▌',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: p.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _preprocessCitations(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?:【(\d+)】|\[(\d+)\])'),
      (m) {
        final idx = m.group(1) ?? m.group(2) ?? '';
        return '[$idx](cite://$idx)';
      },
    );
  }
}

// ── Action row (copy / thumbs / regenerate) ───────────────────────────────────

class MessageActionRow extends StatelessWidget {
  const MessageActionRow({
    super.key,
    required this.message,
    required this.conversationId,
    required this.ref,
    this.onRegenerate,
  });

  final Message message;
  final String conversationId;
  final WidgetRef ref;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final iconColor = p.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _Btn(
            icon: Icons.content_copy_outlined,
            tooltip: '复制',
            color: iconColor,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: message.content));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已复制'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          _Btn(
            icon: message.feedback == Feedback.thumbsUp
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            tooltip: '有帮助',
            color: message.feedback == Feedback.thumbsUp
                ? p.primary
                : iconColor,
            onTap: () => ref
                .read(chatProvider(conversationId).notifier)
                .setFeedback(
                  message.id,
                  message.feedback == Feedback.thumbsUp
                      ? Feedback.none
                      : Feedback.thumbsUp,
                ),
          ),
          _Btn(
            icon: message.feedback == Feedback.thumbsDown
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            tooltip: '需要改进',
            color: message.feedback == Feedback.thumbsDown
                ? p.error
                : iconColor,
            onTap: () => ref
                .read(chatProvider(conversationId).notifier)
                .setFeedback(
                  message.id,
                  message.feedback == Feedback.thumbsDown
                      ? Feedback.none
                      : Feedback.thumbsDown,
                ),
          ),
          if (onRegenerate != null)
            _Btn(
              icon: Icons.refresh,
              tooltip: '重新生成',
              color: iconColor,
              onTap: onRegenerate!,
            ),
        ],
      ),
    );
  }
}

class _Btn extends StatefulWidget {
  const _Btn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(widget.icon, size: 14, color: widget.color),
          ),
        ),
      ),
    );
  }
}
