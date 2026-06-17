import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/chat/presentation/chat_provider.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/citation_drawer.dart';
import '../../features/conversations/presentation/conversations_list.dart';
import '../../features/conversations/presentation/conversations_provider.dart';
import '../../features/conversations/data/conversation_repository.dart';
import '../../features/conversations/domain/conversation.dart';
import '../../features/auth/presentation/auth_provider.dart';
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

// ── Desktop Layout — resizable sidebar ───────────────────────────────────────

class _DesktopScaffold extends StatefulWidget {
  const _DesktopScaffold({required this.conversationId});
  final String? conversationId;

  @override
  State<_DesktopScaffold> createState() => _DesktopScaffoldState();
}

class _DesktopScaffoldState extends State<_DesktopScaffold> {
  double _sidebarWidth = 256;
  static const double _minWidth = 160;
  static const double _maxWidth = 400;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────
          SizedBox(
            width: _sidebarWidth,
            child: Container(
              color: p.bgSidebar,
              child: const ConversationsList(),
            ),
          ),

          // ── Resize handle ─────────────────────────────────────────
          _ResizeHandle(
            onDrag: (dx) {
              setState(() {
                _sidebarWidth =
                    (_sidebarWidth + dx).clamp(_minWidth, _maxWidth);
              });
            },
          ),

          // ── Chat area ────────────────────────────────────────────
          Expanded(
            child: widget.conversationId == null
                ? const _WelcomeScreen()
                : CitationDrawerHost(
                    child: ChatScreen(conversationId: widget.conversationId!),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({required this.onDrag});
  final void Function(double dx) onDrag;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 5,
          color: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _hovering ? 3 : 1,
              color: _hovering ? p.primary : p.divider,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile Layout ─────────────────────────────────────────────────────────────

class _MobileScaffold extends ConsumerWidget {
  const _MobileScaffold({required this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = conversationId == null
        ? const _WelcomeScreen()
        : CitationDrawerHost(
            child: ChatScreen(conversationId: conversationId!),
          );

    return Scaffold(
      // Let Scaffold resize the body when the keyboard opens; ChatScreen's
      // input bar sits at the bottom of the (shrunken) body, landing just
      // above the keyboard.
      drawer: Drawer(
        child: ConversationsList(
          onSelect: () => Navigator.of(context).pop(),
        ),
      ),
      // The top bar lives inside the body (not the appBar slot) wrapped in a
      // SafeArea, so it gets its full height *below* the status bar instead of
      // being squeezed into a fixed 52px that the notch then eats into.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MobileAppBar(
              conversationId: conversationId,
              onNewChat: () async {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final now = DateTime.now();
                final conv = Conversation(
                  id: generateConversationId(),
                  userId: user.id,
                  title: '新对话',
                  createdAt: now,
                  updatedAt: now,
                );
                await ref.read(conversationRepositoryProvider).create(conv);
                ref.read(selectedConversationProvider.notifier).select(conv.id);
              },
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _MobileAppBar extends StatelessWidget {
  const _MobileAppBar({required this.conversationId, required this.onNewChat});
  final String? conversationId;
  final VoidCallback onNewChat;

  /// Display name shown centered in the app bar. Currently the product name;
  /// swap this for the active model name once a real backend is wired in.
  static const String _modelName = 'PathPocket';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // Hamburger
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu, color: p.textSecondary, size: 24),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: '会话列表',
              ),
            ),
            // Centered model name
            Expanded(
              child: Text(
                _modelName,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 18,
                  color: p.textPrimary,
                ),
              ),
            ),
            // New chat quick button
            IconButton(
              icon: Icon(Icons.edit_outlined, color: p.textSecondary, size: 22),
              onPressed: onNewChat,
              tooltip: '新建对话',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Welcome / Empty State ─────────────────────────────────────────────────────

class _WelcomeScreen extends ConsumerWidget {
  const _WelcomeScreen();

  static const _suggestions = [
    (icon: '📋', title: '分析病理报告', subtitle: '上传报告，获取 AI 解读', prompt: '请帮我分析一份病理报告。'),
    (icon: '🔬', title: '鉴别诊断', subtitle: '描述病理特征，辅助鉴别', prompt: '我想做鉴别诊断，请帮我分析以下病理特征。'),
    (icon: '📚', title: '文献引用查询', subtitle: '查找相关病理学文献', prompt: '请帮我查找相关的病理学文献。'),
    (icon: '🖼️', title: '上传病理切片', subtitle: '图像分析与特征提取', prompt: '我想上传一张病理切片做图像分析与特征提取。'),
  ];

  Future<void> _startConversation(
      WidgetRef ref, String prompt) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final now = DateTime.now();
    final conv = Conversation(
      id: generateConversationId(),
      userId: user.id,
      title: prompt,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(conversationRepositoryProvider).create(conv);
    ref.read(selectedConversationProvider.notifier).select(conv.id);
    await ref.read(chatProvider(conv.id).notifier).sendMessage(prompt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = Breakpoints.of(width) == Breakpoint.desktop;
    final isMobile = Breakpoints.of(width) == Breakpoint.mobile;

    return Container(
      color: p.bgPage,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isMobile ? 48 : 56,
                  height: isMobile ? 48 : 56,
                  decoration: BoxDecoration(
                    color: p.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(
                    Icons.biotech_outlined,
                    size: isMobile ? 24 : 28,
                    color: p.primary,
                  ),
                ),
                SizedBox(height: isMobile ? 14 : 20),
                Text(
                  '你好，我是 PathPocket',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isDesktop ? 30 : (isMobile ? 22 : 24),
                    fontWeight: FontWeight.w400,
                    color: p.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'HKUST SmartX Lab · 病理学 AI 助手',
                  style: GoogleFonts.dmSans(
                    fontSize: isMobile ? 13 : 14,
                    color: p.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isMobile ? 24 : 36),
                // Mobile: single column; tablet/desktop: 2 columns
                isMobile
                    ? Column(
                        children: _suggestions
                            .map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _SuggestionCard(
                                    icon: s.icon,
                                    title: s.title,
                                    subtitle: s.subtitle,
                                    mobile: true,
                                    onTap: () =>
                                        _startConversation(ref, s.prompt),
                                  ),
                                ))
                            .toList(),
                      )
                    : GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.4,
                        children: _suggestions
                            .map((s) => _SuggestionCard(
                                  icon: s.icon,
                                  title: s.title,
                                  subtitle: s.subtitle,
                                  mobile: false,
                                  onTap: () =>
                                      _startConversation(ref, s.prompt),
                                ))
                            .toList(),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.mobile,
    required this.onTap,
  });
  final String icon;
  final String title;
  final String subtitle;
  final bool mobile;
  final VoidCallback onTap;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final borderColor = _hovered ? p.primary : p.divider;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: p.bgSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: widget.mobile ? 14 : 12,
          ),
          child: Row(
            children: [
              Text(widget.icon,
                  style: TextStyle(fontSize: widget.mobile ? 20 : 16)),
              SizedBox(width: widget.mobile ? 12 : 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.tiny(context),
                    ),
                  ],
                ),
              ),
              if (widget.mobile)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: p.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
