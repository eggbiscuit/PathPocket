import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation.dart';
import 'conversations_provider.dart';

class ConversationsList extends ConsumerWidget {
  const ConversationsList({super.key, this.onSelect});

  /// Optional callback fired after a list item is tapped — useful on mobile
  /// to close the drawer.
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          onNewChat: user == null
              ? null
              : () async {
                  await _createConversation(ref, user.id);
                  onSelect?.call();
                },
        ),
        const Divider(height: 1),
        Expanded(
          child: conversationsAsync.when(
            data: (items) {
              if (items.isEmpty) return const _Empty();
              return _GroupedList(items: items, onSelect: onSelect);
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '加载会话失败：$e',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ),
        if (user != null) _Footer(user: user),
      ],
    );
  }

  static Future<void> _createConversation(WidgetRef ref, String userId) async {
    final now = DateTime.now();
    final conv = Conversation(
      id: generateConversationId(),
      userId: userId,
      title: '新对话',
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(conversationRepositoryProvider).create(conv);
    ref.read(selectedConversationProvider.notifier).select(conv.id);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNewChat});
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '会话历史',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: '新建对话',
            onPressed: onNewChat,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          '还没有对话\n点击右上角 + 开始第一次咨询',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.timestamp, fontSize: 13),
        ),
      ),
    );
  }
}

class _GroupedList extends ConsumerWidget {
  const _GroupedList({required this.items, required this.onSelect});
  final List<Conversation> items;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedConversationProvider);
    final groups = _groupByDate(items);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: groups.fold<int>(
        0,
        (sum, g) => sum + 1 + g.items.length,
      ),
      itemBuilder: (context, idx) {
        var i = idx;
        for (final g in groups) {
          if (i == 0) return _SectionHeader(label: g.label);
          i -= 1;
          if (i < g.items.length) {
            final c = g.items[i];
            return _ConversationTile(
              conversation: c,
              selected: c.id == selected,
              onTap: () {
                ref
                    .read(selectedConversationProvider.notifier)
                    .select(c.id);
                onSelect?.call();
              },
            );
          }
          i -= g.items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: selected ? AppColors.aiBubble : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 18, color: AppColors.timestamp),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, size: 18),
                tooltip: '更多',
                onSelected: (v) => _handleAction(context, ref, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    final repo = ref.read(conversationRepositoryProvider);
    if (action == 'rename') {
      final newTitle = await _promptRename(context, conversation.title);
      if (newTitle != null && newTitle.isNotEmpty) {
        await repo.rename(conversation.id, newTitle);
      }
    } else if (action == 'delete') {
      final ok = await _confirmDelete(context);
      if (ok == true) {
        await repo.remove(conversation.id);
        if (ref.read(selectedConversationProvider) == conversation.id) {
          ref.read(selectedConversationProvider.notifier).select(null);
        }
      }
    }
  }

  Future<String?> _promptRename(BuildContext context, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('该对话及全部消息将被删除，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.timestamp,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.person, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              user.displayName ?? user.phone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout, size: 18),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _Group {
  _Group(this.label, this.items);
  final String label;
  final List<Conversation> items;
}

List<_Group> _groupByDate(List<Conversation> items) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
  final startOfPast7 = startOfToday.subtract(const Duration(days: 7));

  final today = <Conversation>[];
  final yesterday = <Conversation>[];
  final past7 = <Conversation>[];
  final earlier = <Conversation>[];

  for (final c in items) {
    if (!c.updatedAt.isBefore(startOfToday)) {
      today.add(c);
    } else if (!c.updatedAt.isBefore(startOfYesterday)) {
      yesterday.add(c);
    } else if (!c.updatedAt.isBefore(startOfPast7)) {
      past7.add(c);
    } else {
      earlier.add(c);
    }
  }

  return [
    if (today.isNotEmpty) _Group('今天', today),
    if (yesterday.isNotEmpty) _Group('昨天', yesterday),
    if (past7.isNotEmpty) _Group('过去 7 天', past7),
    if (earlier.isNotEmpty) _Group('更早', earlier),
  ];
}
