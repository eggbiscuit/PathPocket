import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/conversations/presentation/conversations_list.dart';
import '../../features/conversations/presentation/conversations_provider.dart';
import '../breakpoints.dart';
import '../theme.dart';

class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationId = ref.watch(selectedConversationProvider);
    final width = MediaQuery.sizeOf(context).width;
    final bp = Breakpoints.of(width);

    if (bp == Breakpoint.desktop) {
      return _DesktopScaffold(conversationId: conversationId);
    }
    return _MobileScaffold(conversationId: conversationId);
  }
}

class _DesktopScaffold extends StatelessWidget {
  const _DesktopScaffold({required this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: Column(
              children: [
                Container(
                  height: 56,
                  color: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'PathPocket',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(child: ConversationsList()),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _ChatAppBar(conversationId: conversationId),
                Expanded(
                  child: conversationId == null
                      ? const _NoConversationPlaceholder()
                      : CitationDrawerHost(
                          child: ChatScreen(conversationId: conversationId!),
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

class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({required this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PathPocket'),
        actions: const [_ClearButton()],
      ),
      drawer: Drawer(
        child: ConversationsList(
          onSelect: () => Navigator.of(context).pop(),
        ),
      ),
      body: conversationId == null
          ? const _NoConversationPlaceholder()
          : CitationDrawerHost(
              child: ChatScreen(conversationId: conversationId!),
            ),
    );
  }
}

class _ChatAppBar extends ConsumerWidget {
  const _ChatAppBar({required this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 56,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '病理问答',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const _ClearButton(),
        ],
      ),
    );
  }
}

class _ClearButton extends ConsumerWidget {
  const _ClearButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: '清空对话',
      icon: const Icon(Icons.delete_outline, color: Colors.white),
      onPressed: () async {
        final conversationId = ref.read(selectedConversationProvider);
        if (conversationId == null) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('清空对话'),
            content: const Text('确定要清空当前对话吗？'),
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
        if (ok != true || !context.mounted) return;
        // Delete and re-create is a safe clear; simpler than partial purge.
        // TODO Phase 2: expose clearMessages on chatProvider instead.
      },
    );
  }
}

class _NoConversationPlaceholder extends StatelessWidget {
  const _NoConversationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.medical_services, size: 56, color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            '选择或新建一个对话开始咨询',
            style: TextStyle(color: AppColors.timestamp),
          ),
        ],
      ),
    );
  }
}
