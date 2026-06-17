import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../domain/message.dart';
import 'chat_input_bar.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';
import 'smart_scroll_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final SmartScrollController _smartScroll;
  String? _lastErrorShown;
  int _prevMessageCount = 0;
  String _prevLastContent = '';

  @override
  void initState() {
    super.initState();
    _smartScroll = SmartScrollController();
    _smartScroll.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _smartScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(widget.conversationId));
    final p = context.palette;

    ref.listen(chatProvider(widget.conversationId), (prev, next) {
      final newCount = next.messages.length;
      final newContent =
          next.messages.isNotEmpty ? next.messages.last.content : '';
      if (newCount != _prevMessageCount || newContent != _prevLastContent) {
        _smartScroll.onNewContent();
        _prevMessageCount = newCount;
        _prevLastContent = newContent;
      }
      final err = next.errorMessage;
      if (err != null && err != _lastErrorShown) {
        _lastErrorShown = err;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              backgroundColor: p.error,
              content: Text(err),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ));
        });
      } else if (err == null) {
        _lastErrorShown = null;
      }
    });

    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      color: p.bgPage,
      child: Stack(
        children: [
          // ── Message list ──────────────────────────────────────
          Positioned.fill(
            bottom: 0,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
                children: [
                  Expanded(child: _buildList(state)),
                  if (state.isLoading) _buildThinkingBar(p),
                  // Reserve space for the input bar + keyboard
                  SizedBox(height: 96 + viewInsets),
                ],
              ),
            ),
          ),
          // ── Floating input bar — lifts above the keyboard ─────
          Positioned(
            left: 0,
            right: 0,
            bottom: viewInsets,
            child: ChatInputBar(
              conversationId: widget.conversationId,
              isLoading: state.isLoading,
            ),
          ),
          // ── Jump-to-bottom FAB ────────────────────────────────
          if (_smartScroll.showJumpFab)
            Positioned(
              right: 16,
              bottom: 110 + viewInsets,
              child: _JumpFab(onTap: _smartScroll.jumpToBottom),
            ),
        ],
      ),
    );
  }

  Widget _buildList(ChatState state) {
    if (state.messages.isEmpty) {
      return const SizedBox.shrink(); // placeholder handled by shell
    }

    final streaming = state.isLoading;

    return ListView.builder(
      controller: _smartScroll.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      itemCount: state.messages.length,
      itemBuilder: (_, i) {
        final msg = state.messages[i];
        final isLastAssistant = !streaming &&
            i == state.messages.length - 1 &&
            msg.role == MessageRole.assistant;
        final showRegenerate = isLastAssistant ||
            (msg.role == MessageRole.assistant &&
                msg.status == MessageStatus.error &&
                !streaming);

        return MessageBubble(
          message: msg,
          conversationId: widget.conversationId,
          onStop: streaming && msg.role == MessageRole.assistant
              ? () => ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .stopGeneration()
              : null,
          onRegenerate: showRegenerate
              ? () => ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .regenerate(msg.id)
              : null,
        );
      },
    );
  }

  Widget _buildThinkingBar(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: p.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI 正在思考…',
            style: AppTextStyles.caption(context),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => ref
                .read(chatProvider(widget.conversationId).notifier)
                .stopGeneration(),
            child: Row(
              children: [
                Icon(Icons.stop_circle_outlined,
                    size: 13, color: p.error),
                const SizedBox(width: 4),
                Text(
                  '停止',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: p.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Jump-to-bottom FAB ────────────────────────────────────────────────────────

class _JumpFab extends StatelessWidget {
  const _JumpFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: p.bgSurface,
          shape: BoxShape.circle,
          border: Border.all(
            color: p.divider,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0x30000000)
                  : const Color(0x12000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.keyboard_arrow_down,
          size: 20,
          color: p.textSecondary,
        ),
      ),
    );
  }
}

