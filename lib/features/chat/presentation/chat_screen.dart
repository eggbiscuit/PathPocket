import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  String? _shownError;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _inputFocus.requestFocus();
  }

  void _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('确定要清空当前所有对话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(chatProvider.notifier).clearChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    ref.listen(chatProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0) ||
          (next.messages.isNotEmpty &&
              prev != null &&
              prev.messages.isNotEmpty &&
              next.messages.last.content !=
                  prev.messages.last.content)) {
        _scrollToBottom();
      }

      final err = next.errorMessage;
      if (err != null && err != _shownError) {
        _shownError = err;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(err),
              behavior: SnackBarBehavior.floating,
            ),
          );
      } else if (err == null) {
        _shownError = null;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PathPocket',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: '清空对话',
            icon: const Icon(Icons.delete_outline),
            onPressed: state.messages.isEmpty ? null : _confirmClear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList(state)),
            if (state.isLoading) _buildThinkingHint(),
            _buildInputBar(state.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState state) {
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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length,
      itemBuilder: (_, i) => MessageBubble(message: state.messages[i]),
    );
  }

  Widget _buildThinkingHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'AI 正在思考...',
            style: TextStyle(color: AppColors.timestamp, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAEAEA), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
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
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
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
