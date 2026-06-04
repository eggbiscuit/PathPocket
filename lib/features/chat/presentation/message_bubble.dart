import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme.dart';
import '../domain/message.dart';
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

  static const _radius = BorderRadius.all(Radius.circular(12));
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) _buildBotIcon(),
              if (!isUser) const SizedBox(width: 8),
              Flexible(child: _buildBubble(context, ref, isUser)),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 36,
              right: isUser ? 4 : 0,
            ),
            child: Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(
                    color: AppColors.timestamp,
                    fontSize: 11,
                  ),
                ),
                if (!isUser && message.status != MessageStatus.streaming)
                  ..._buildAssistantActions(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotIcon() {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.medical_services, color: Colors.white, size: 16),
    );
  }

  Widget _buildBubble(BuildContext context, WidgetRef ref, bool isUser) {
    if (isUser) {
      return Container(
        padding: _padding,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: _radius,
        ),
        child: Text(
          message.content,
          style: const TextStyle(
            color: AppColors.userBubbleText,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      );
    }

    final isStreaming = message.status == MessageStatus.streaming;
    final isInterrupted = message.wasInterrupted;

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.aiBubble,
        borderRadius: _radius,
        border: isInterrupted
            ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.content.isEmpty && isStreaming)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            _MarkdownWithCitations(
              content: message.content,
              citations: message.citations,
              onCitationTap: (tagContent) =>
                  _openCitation(ref, tagContent),
            ),
          if (isInterrupted)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message.status == MessageStatus.stopped
                    ? '已停止生成'
                    : '生成失败',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAssistantActions(BuildContext context, WidgetRef ref) {
    return [
      const SizedBox(width: 8),
      _ActionIcon(
        icon: Icons.copy,
        tooltip: '复制',
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: message.content));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('已复制'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
      _ActionIcon(
        icon: message.feedback == Feedback.thumbsUp
            ? Icons.thumb_up
            : Icons.thumb_up_outlined,
        tooltip: '有帮助',
        onTap: () {
          ref.read(chatProvider(conversationId).notifier).setFeedback(
                message.id,
                message.feedback == Feedback.thumbsUp
                    ? Feedback.none
                    : Feedback.thumbsUp,
              );
        },
      ),
      _ActionIcon(
        icon: message.feedback == Feedback.thumbsDown
            ? Icons.thumb_down
            : Icons.thumb_down_outlined,
        tooltip: '需要改进',
        onTap: () {
          ref.read(chatProvider(conversationId).notifier).setFeedback(
                message.id,
                message.feedback == Feedback.thumbsDown
                    ? Feedback.none
                    : Feedback.thumbsDown,
              );
        },
      ),
      if (onRegenerate != null)
        _ActionIcon(
          icon: Icons.refresh,
          tooltip: '重新生成',
          onTap: onRegenerate!,
        ),
    ];
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

  String _formatTime(DateTime t) {
    final local = t.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

/// MarkdownBody wrapper that turns [N] tags into tappable chips via
/// a custom inline syntax that encodes the citation index as a link target.
class _MarkdownWithCitations extends StatelessWidget {
  const _MarkdownWithCitations({
    required this.content,
    required this.citations,
    required this.onCitationTap,
  });

  final String content;
  final List<Citation> citations;
  final void Function(String index) onCitationTap;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: _preprocessCitations(content),
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          color: AppColors.aiBubbleText,
          fontSize: 15,
          height: 1.5,
        ),
        strong: const TextStyle(
          color: AppColors.aiBubbleText,
          fontWeight: FontWeight.w700,
        ),
        code: const TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Color(0xFFE3EDED),
          fontSize: 13,
        ),
        a: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTapLink: (text, href, _) {
        if (href != null && href.startsWith('cite://')) {
          onCitationTap(href.substring('cite://'.length));
        }
      },
    );
  }

  /// Converts `[1]` and `【1】` patterns to Markdown links that encode the
  /// citation index in their href (`[1](cite://1)`). MarkdownBody renders
  /// these as styled links, and onTapLink fires the drawer callback.
  static String _preprocessCitations(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?:【\d+】|\[(\d+)\])'),
      (m) {
        final idx = m.group(1) ?? m.group(0)!.replaceAll(RegExp(r'[【】\[\]]'), '');
        return '[​$idx​](cite://$idx)';
      },
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, size: 14, color: AppColors.timestamp),
        ),
      ),
    );
  }
}
