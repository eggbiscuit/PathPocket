import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

// ── Desktop Layout ────────────────────────────────────────────────────────────

class _DesktopScaffold extends StatelessWidget {
  const _DesktopScaffold({required this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg =
        isDark ? AppColors.bgSidebarDark : AppColors.bgSidebar;

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────
          Container(
            width: 256,
            color: sidebarBg,
            child: const ConversationsList(),
          ),
          // Subtle divider
          Container(
            width: 1,
            color: isDark ? AppColors.dividerDark : AppColors.divider,
          ),
          // ── Chat area ────────────────────────────────────────────
          Expanded(
            child: conversationId == null
                ? const _WelcomeScreen()
                : CitationDrawerHost(
                    child: ChatScreen(conversationId: conversationId!),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile Layout ─────────────────────────────────────────────────────────────

class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({required this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar — use inline header inside ChatScreen / WelcomeScreen
      appBar: _MobileAppBar(),
      drawer: Drawer(
        child: ConversationsList(
          onSelect: () => Navigator.of(context).pop(),
        ),
      ),
      body: conversationId == null
          ? const _WelcomeScreen()
          : CitationDrawerHost(
              child: ChatScreen(conversationId: conversationId!),
            ),
    );
  }
}

class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgPageDark : AppColors.bgPage,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.divider,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(
                  Icons.menu,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                  size: 22,
                ),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            Text(
              'PathPocket',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 18,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
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
    (icon: '📋', title: '分析病理报告', subtitle: '上传报告，获取 AI 解读'),
    (icon: '🔬', title: '鉴别诊断', subtitle: '描述病理特征，辅助鉴别'),
    (icon: '📚', title: '文献引用查询', subtitle: '查找相关病理学文献'),
    (icon: '🖼️', title: '上传病理切片', subtitle: '图像分析与特征提取'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = Breakpoints.of(width) == Breakpoint.desktop;

    return Container(
      color: isDark ? AppColors.bgPageDark : AppColors.bgPage,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo mark
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primaryContainerDark
                        : AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(
                    Icons.biotech_outlined,
                    size: 28,
                    color: isDark ? AppColors.primaryDark : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '你好，我是 PathPocket',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isDesktop ? 30 : 24,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'HKUST SmartX Lab · 病理学 AI 助手',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                GridView.count(
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
                            isDark: isDark,
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
    required this.isDark,
  });
  final String icon;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _hovered
        ? (widget.isDark ? AppColors.primaryDark : AppColors.primary)
        : (widget.isDark ? AppColors.dividerDark : AppColors.divider);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.bgSurfaceDark : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: widget.isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
