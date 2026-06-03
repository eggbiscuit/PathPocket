import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme.dart';
import '../domain/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  static const _radius = BorderRadius.all(Radius.circular(12));
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  @override
  Widget build(BuildContext context) {
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
              Flexible(child: _buildBubble(isUser)),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 36,
              right: isUser ? 4 : 0,
            ),
            child: Text(
              _formatTime(message.timestamp),
              style: const TextStyle(
                color: AppColors.timestamp,
                fontSize: 11,
              ),
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
      child: const Icon(
        Icons.medical_services,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildBubble(bool isUser) {
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

    return Container(
      padding: _padding,
      decoration: const BoxDecoration(
        color: AppColors.aiBubble,
        borderRadius: _radius,
      ),
      child: message.content.isEmpty
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : MarkdownBody(
              data: message.content,
              selectable: true,
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
                listBullet: const TextStyle(
                  color: AppColors.aiBubbleText,
                  fontSize: 15,
                ),
                code: const TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: Color(0xFFE3EDED),
                ),
              ),
            ),
    );
  }

  String _formatTime(DateTime t) {
    final local = t.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
