import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/breakpoints.dart';
import '../../../core/theme.dart';
import '../domain/message.dart';
import '../../image_input/presentation/image_viewer_screen.dart';
import 'citation_drawer.dart';
import 'message_content.dart';

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
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = Breakpoints.of(width) == Breakpoint.mobile;

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 180),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isUser ? (isMobile ? 40 : 64) : (isMobile ? 12 : 16),
          4,
          isUser ? (isMobile ? 12 : 16) : (isMobile ? 12 : 64),
          4,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
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
    final p = context.palette;
    final isStreaming = message.status == MessageStatus.streaming;
    final isInterrupted = message.wasInterrupted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image attachments
        if (message.images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
        message.content.isEmpty && isStreaming
            ? const StreamingIndicator()
            : MarkdownContent(
                content: message.content,
                citations: message.citations,
                isStreaming: isStreaming,
                onCitationTap: (tag) => _openCitation(ref, tag),
              ),
        // Error / stopped indicator
        if (isInterrupted)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              message.status == MessageStatus.stopped ? '已停止生成' : '生成失败',
              style: AppTextStyles.tiny(context).copyWith(color: p.error),
            ),
          ),
        // Action row
        if (!isStreaming)
          MessageActionRow(
            message: message,
            conversationId: conversationId,
            ref: ref,
            onRegenerate: onRegenerate,
          ),
      ],
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

// ── Timestamp ─────────────────────────────────────────────────────────────────

class _Timestamp extends StatelessWidget {
  const _Timestamp({required this.message, required this.isUser});
  final Message message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final local = message.timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return Text(
      '$hh:$mm',
      style: AppTextStyles.tiny(context),
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
