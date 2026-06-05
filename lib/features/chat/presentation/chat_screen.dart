import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../domain/message.dart';
import '../../image_input/presentation/image_picker_bar.dart';
import '../../image_input/presentation/image_viewer_screen.dart';
import 'chat_provider.dart';
import 'citation_drawer.dart';
import 'message_bubble.dart';
import 'smart_scroll_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  late final SmartScrollController _smartScroll;
  final FocusNode _inputFocus = FocusNode();
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
    _input.dispose();
    _smartScroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    ref
        .read(chatProvider(widget.conversationId).notifier)
        .sendMessage(text);
    _inputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(widget.conversationId));

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
              backgroundColor: AppColors.error,
              content: Text(err),
              behavior: SnackBarBehavior.floating,
            ));
        });
      } else if (err == null) {
        _lastErrorShown = null;
      }
    });

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _buildList(state)),
          if (state.isLoading) _buildThinkingBar(),
          _buildInputBar(state.isLoading),
        ],
      ),
      floatingActionButton: _smartScroll.showJumpFab
          ? FloatingActionButton.small(
              tooltip: '回到最新',
              onPressed: _smartScroll.jumpToBottom,
              child: const Icon(Icons.keyboard_arrow_down),
            )
          : null,
    );
  }

  Widget _buildList(ChatState state) {
    if (state.messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '向 PathPocket 提问，开始你的病理咨询。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.timestamp, fontSize: 14),
          ),
        ),
      );
    }

    final streaming = state.isLoading;

    return ListView.builder(
      controller: _smartScroll.scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      itemCount: state.messages.length,
      itemBuilder: (_, i) {
        final msg = state.messages[i];
        final isLastAssistant = !streaming &&
            i == state.messages.length - 1 &&
            msg.role == MessageRole.assistant;

        return MessageBubble(
          message: msg,
          conversationId: widget.conversationId,
          onStop: streaming && msg.role == MessageRole.assistant
              ? () => ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .stopGeneration()
              : null,
          onRegenerate: isLastAssistant
              ? () => ref
                  .read(chatProvider(widget.conversationId).notifier)
                  .regenerate(msg.id)
              : null,
        );
      },
    );
  }

  Widget _buildThinkingBar() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'AI 正在思考...',
            style: TextStyle(color: AppColors.timestamp, fontSize: 12),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => ref
                .read(chatProvider(widget.conversationId).notifier)
                .stopGeneration(),
            icon: const Icon(Icons.stop, size: 14),
            label: const Text('停止', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePicker(BuildContext context) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const ImagePickerSheet(),
    );
    if (result == null || !mounted) return;
    ref
        .read(chatProvider(widget.conversationId).notifier)
        .addPendingImage(result);
  }

  Widget _buildInputBar(bool isLoading) {
    final pendingImages =
        ref.watch(chatProvider(widget.conversationId).select((s) => s.pendingImages));

    return ImageDropTarget(
      onDropped: (img) => ref
          .read(chatProvider(widget.conversationId).notifier)
          .addPendingImage(img),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingImages.isNotEmpty)
              _PendingImageStrip(
                images: pendingImages,
                onRemove: (id) => ref
                    .read(chatProvider(widget.conversationId).notifier)
                    .removePendingImage(id),
                onTap: (img) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ImageViewerScreen.fromBytes(bytes: img.bytes),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '附加图片',
                    icon: const Icon(Icons.attach_file),
                    color: AppColors.primary,
                    onPressed:
                        isLoading ? null : () => _showImagePicker(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      enabled: !isLoading,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: isLoading ? '等待回复中...' : '请输入你的问题',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSendButton(isLoading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(bool isLoading) {
    if (isLoading) {
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _handleSend,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.send, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Horizontal strip showing pending images with remove buttons.
class _PendingImageStrip extends StatelessWidget {
  const _PendingImageStrip({
    required this.images,
    required this.onRemove,
    required this.onTap,
  });

  final List images;
  final void Function(String id) onRemove;
  final void Function(dynamic img) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final img = images[i];
          return GestureDetector(
            onTap: () => onTap(img),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    img.bytes,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => onRemove(img.id),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shows a citation bottom sheet / side panel.
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
          const VerticalDivider(width: 1),
          SizedBox(
            width: 340,
            child: _CitationPanel(
              citations: drawerState.citations,
              focusId: drawerState.focus?.citationId,
              onClose: () => ref.read(citationDrawerProvider.notifier).close(),
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
            onClose: () => ref.read(citationDrawerProvider.notifier).close(),
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
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Text(
                  '参考文献',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: citations.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (_, i) {
                final c = citations[i];
                final isFocused = c.id == focusId;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : null,
                    borderRadius: BorderRadius.circular(8),
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
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.snippet,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.aiBubbleText,
                          height: 1.5,
                        ),
                      ),
                      if (c.source != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            c.source!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.timestamp,
                            ),
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
