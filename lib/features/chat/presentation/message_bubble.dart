import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme.dart';
import '../domain/message.dart';
import '../../image_input/presentation/image_viewer_screen.dart';
import 'chat_provider.dart';
import 'citation_drawer.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.conversationId,
    this.onRegenerate,
    this.onStop,
  });

  final Message message;
  final String conversationId;
  final VoidCallback? onRegenerate;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == MessageRole.user;
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 180),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isUser ? 48 : 16,
          4,
          isUser ? 16 : 48,
          4,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser) _buildBotLabel(context),
            const SizedBox(height: 4),
            isUser
                ? _UserBubble(message: message)
                : _AiBubble(
                    message: message,
                    conversationId: conversationId,
                    onStop: onStop,
                    onRegenerate: onRegenerate,
                    ref: ref,
                  ),
            const SizedBox(height: 2),
            _Timestamp(message: message, isUser: isUser),
          ],
        ),
      ),
    );
  }

  Widget _buildBotLabel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primaryContainerDark
                : AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.biotech_outlined,
            size: 13,
            color: isDark ? AppColors.primaryDark : AppColors.primary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'PathPocket',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.primaryDark : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

// ── User bubble ───────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.userBubble,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bubble),
          topRight: Radius.circular(AppRadius.bubble),
          bottomLeft: Radius.circular(AppRadius.bubble),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        message.content,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          height: 1.55,
          color: AppColors.userBubbleText,
        ),
      ),
    );
  }
}

// ── AI bubble ─────────────────────────────────────────────────────────────────

class _AiBubble extends StatelessWidget {
  const _AiBubble({
    required this.message,
    required this.conversationId,
    required this.ref,
    this.onStop,
    this.onRegenerate,
  });

  final Message message;
  final String conversationId;
  final WidgetRef ref;
  final VoidCallback? onStop;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isStreaming = message.status == MessageStatus.streaming;
    final isInterrupted = message.wasInterrupted;
    final borderColor =
        isDark ? AppColors.aiBubbleBorderDark : AppColors.aiBubbleBorder;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(AppRadius.bubble),
          bottomLeft: Radius.circular(AppRadius.bubble),
          bottomRight: Radius.circular(AppRadius.bubble),
        ),
        border: Border(
          left: BorderSide(color: borderColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x28000000)
                : const Color(0x0C000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image attachments
          if (message.images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _ImageRow(
                images: message.images,
                onTap: (img) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageViewerScreen.fromUri(uri: img.uri),
                  ),
                ),
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: message.content.isEmpty && isStreaming
                ? _StreamingIndicator(isDark: isDark)
                : _MarkdownContent(
                    content: message.content,
                    citations: message.citations,
                    isDark: isDark,
                    isStreaming: isStreaming,
                    onCitationTap: (tag) => _openCitation(ref, tag),
                  ),
          ),
          // Error / stopped indicator
          if (isInterrupted)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                message.status == MessageStatus.stopped ? '已停止生成' : '生成失败',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.error,
                ),
              ),
            ),
          // Action row
          if (!isStreaming)
            _ActionRow(
              message: message,
              conversationId: conversationId,
              ref: ref,
              onRegenerate: onRegenerate,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  void _openCitation(WidgetRef ref, String tagContent) {
    if (message.citations.isEmpty) return;
    final index = int.tryParse(tagContent);
    final citation =
        index != null && index > 0 && index <= message.citations.length
            ? message.citations[index - 1]
            : message.citations.first;
    ref.read(citationDrawerProvider.notifier).openFor(
          messageId: message.id,
          citations: message.citations,
          citationId: citation.id,
        );
  }
}

// ── Streaming indicator (dots) ────────────────────────────────────────────────

class _StreamingIndicator extends StatefulWidget {
  const _StreamingIndicator({required this.isDark});
  final bool isDark;

  @override
  State<_StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<_StreamingIndicator>
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
                color: (widget.isDark ? AppColors.primaryDark : AppColors.primary)
                    .withValues(alpha: opacity),
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

class _MarkdownContent extends StatefulWidget {
  const _MarkdownContent({
    required this.content,
    required this.citations,
    required this.isDark,
    required this.isStreaming,
    required this.onCitationTap,
  });

  final String content;
  final List<Citation> citations;
  final bool isDark;
  final bool isStreaming;
  final void Function(String) onCitationTap;

  @override
  State<_MarkdownContent> createState() => _MarkdownContentState();
}

class _MarkdownContentState extends State<_MarkdownContent>
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
    final textColor =
        widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor =
        widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

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
              backgroundColor: widget.isDark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF0EDEA),
              color: textColor,
            ),
            a: GoogleFonts.dmSans(
              fontSize: 15,
              color: widget.isDark ? AppColors.primaryDark : AppColors.primary,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: widget.isDark
                      ? AppColors.primaryDark
                      : AppColors.primary,
                  width: 3,
                ),
              ),
              color: widget.isDark
                  ? AppColors.primaryContainerDark
                  : AppColors.primaryContainer,
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
                  color: widget.isDark
                      ? AppColors.primaryDark
                      : AppColors.primary,
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.message,
    required this.conversationId,
    required this.ref,
    required this.isDark,
    this.onRegenerate,
  });

  final Message message;
  final String conversationId;
  final WidgetRef ref;
  final bool isDark;
  final VoidCallback? onRegenerate;

  Color get _iconColor =>
      isDark ? AppColors.textTertiaryDark : AppColors.textTertiary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        children: [
          _Btn(
            icon: Icons.content_copy_outlined,
            tooltip: '复制',
            color: _iconColor,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: message.content));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已复制', style: GoogleFonts.dmSans()),
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
                ? (isDark ? AppColors.primaryDark : AppColors.primary)
                : _iconColor,
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
                ? AppColors.error
                : _iconColor,
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
              color: _iconColor,
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

// ── Timestamp ─────────────────────────────────────────────────────────────────

class _Timestamp extends StatelessWidget {
  const _Timestamp({required this.message, required this.isUser});
  final Message message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final local = message.timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return Text(
      '$hh:$mm',
      style: GoogleFonts.dmSans(
        fontSize: 11,
        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
      ),
    );
  }
}

// ── Image row ─────────────────────────────────────────────────────────────────

class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.images, required this.onTap});
  final List<ImageAttachment> images;
  final void Function(ImageAttachment) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: images.map((img) => _thumb(img)).toList(),
    );
  }

  Widget _thumb(ImageAttachment img) {
    final Widget image = img.uri.startsWith('data:')
        ? Image.memory(
            Uri.parse(img.uri.replaceFirst(
                    'data:', 'data:application/octet-stream;'))
                .data!
                .contentAsBytes(),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          )
        : Image.network(img.uri, width: 80, height: 80, fit: BoxFit.cover);

    return GestureDetector(
      onTap: () => onTap(img),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: image,
      ),
    );
  }
}
