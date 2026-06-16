import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../settings/presentation/settings_screen.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation.dart';
import 'conversations_provider.dart';

class ConversationsList extends ConsumerWidget {
  const ConversationsList({super.key, this.onSelect});

  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final conversationsAsync = ref.watch(conversationsStreamProvider);
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SidebarHeader(
          onNewChat: user == null
              ? null
              : () async {
                  await _createConversation(ref, user.id);
                  onSelect?.call();
                },
        ),
        Expanded(
          child: conversationsAsync.when(
            data: (items) {
              if (items.isEmpty) return const _Empty();
              return _GroupedList(items: items, onSelect: onSelect);
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.primary,
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '加载失败：$e',
                style: AppTextStyles.caption(context).copyWith(color: p.error),
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

// ── Sidebar header with logo + new chat button ────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.onNewChat});
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              'PathPocket',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 17,
                color: p.textPrimary,
              ),
            ),
          ),
          // New chat button
          SizedBox(
            width: double.infinity,
            height: 36,
            child: TextButton.icon(
              onPressed: onNewChat,
              icon: Icon(
                Icons.add,
                size: 16,
                color: p.primary,
              ),
              label: Text(
                '新建对话',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.primary,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: p.primaryContainer,
                foregroundColor: p.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          '还没有对话\n点击"新建对话"开始',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            height: 1.6,
            color: context.palette.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ── Grouped list ──────────────────────────────────────────────────────────────

class _GroupedList extends ConsumerWidget {
  const _GroupedList({
    required this.items,
    required this.onSelect,
  });
  final List<Conversation> items;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedConversationProvider);
    final groups = _groupByDate(items);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: groups.fold<int>(0, (sum, g) => sum + 1 + g.items.length),
      itemBuilder: (context, idx) {
        var i = idx;
        for (final g in groups) {
          if (i == 0) return _SectionLabel(label: g.label);
          i -= 1;
          if (i < g.items.length) {
            final c = g.items[i];
            return _ConversationTile(
              conversation: c,
              selected: c.id == selected,
              onTap: () {
                ref.read(selectedConversationProvider.notifier).select(c.id);
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

// ── Conversation tile ─────────────────────────────────────────────────────────

class _ConversationTile extends ConsumerStatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });
  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  ConsumerState<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends ConsumerState<_ConversationTile> {
  bool _hovered = false;

  Color _bg(AppPalette p) {
    if (widget.selected) return p.bgSidebarActive;
    if (_hovered) return p.bgSidebarHover;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: _bg(p),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                if (_hovered || widget.selected)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      size: 16,
                      color: p.textTertiary,
                    ),
                    tooltip: '更多',
                    onSelected: (v) => _handleAction(context, v),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('重命名',
                            style: GoogleFonts.dmSans(fontSize: 13)),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('删除',
                            style: GoogleFonts.dmSans(
                                fontSize: 13, color: p.error)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final repo = ref.read(conversationRepositoryProvider);
    if (action == 'rename') {
      final newTitle = await _promptRename(context, widget.conversation.title);
      if (newTitle != null && newTitle.isNotEmpty) {
        await repo.rename(widget.conversation.id, newTitle);
      }
    } else if (action == 'delete') {
      final ok = await _confirmDelete(context);
      if (ok == true) {
        await repo.remove(widget.conversation.id);
        if (ref.read(selectedConversationProvider) == widget.conversation.id) {
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
        title: Text('重命名对话', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
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
            child: Text('保存', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final p = context.palette;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除对话', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        content: Text('该对话及全部消息将被永久删除。',
            style: GoogleFonts.dmSans(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除',
                style: GoogleFonts.dmSans(
                    color: p.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.palette.textTertiary,
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends ConsumerWidget {
  const _Footer({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: p.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: p.primaryContainer,
            child: Icon(
              Icons.person,
              size: 15,
              color: p.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              user.displayName ?? user.phone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: p.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: '设置',
            icon: Icon(
              Icons.settings_outlined,
              size: 17,
              color: p.textTertiary,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: '退出登录',
            icon: Icon(
              Icons.logout,
              size: 17,
              color: p.textTertiary,
            ),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

// ── Date grouping helpers ─────────────────────────────────────────────────────

class _Group {
  _Group(this.label, this.items);
  final String label;
  final List<Conversation> items;
}

List<_Group> _groupByDate(List<Conversation> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final past7 = today.subtract(const Duration(days: 7));

  final todayList = <Conversation>[];
  final yesterdayList = <Conversation>[];
  final past7List = <Conversation>[];
  final earlierList = <Conversation>[];

  for (final c in items) {
    if (!c.updatedAt.isBefore(today)) {
      todayList.add(c);
    } else if (!c.updatedAt.isBefore(yesterday)) {
      yesterdayList.add(c);
    } else if (!c.updatedAt.isBefore(past7)) {
      past7List.add(c);
    } else {
      earlierList.add(c);
    }
  }

  return [
    if (todayList.isNotEmpty) _Group('今天', todayList),
    if (yesterdayList.isNotEmpty) _Group('昨天', yesterdayList),
    if (past7List.isNotEmpty) _Group('过去 7 天', past7List),
    if (earlierList.isNotEmpty) _Group('更早', earlierList),
  ];
}
