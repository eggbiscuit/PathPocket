import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../domain/message.dart';
import '../../image_input/data/image_input_service.dart';
import '../../image_input/presentation/image_picker_bar.dart';
import '../../image_input/presentation/image_viewer_screen.dart';
import 'chat_provider.dart';
import 'citation_drawer.dart';
import 'message_bubble.dart';
import 'smart_scroll_controller.dart';
import 'voice_input_button.dart';

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
    _input.addListener(() => setState(() {}));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              content: Text(err, style: GoogleFonts.dmSans()),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ));
        });
      } else if (err == null) {
        _lastErrorShown = null;
      }
    });

    return Container(
      color: isDark ? AppColors.bgPageDark : AppColors.bgPage,
      child: Stack(
        children: [
          // ── Message list ──────────────────────────────────────
          Positioned.fill(
            bottom: 0,
            child: Column(
              children: [
                Expanded(child: _buildList(state, isDark)),
                if (state.isLoading) _buildThinkingBar(isDark),
                // Reserve space for the input bar
                const SizedBox(height: 96),
              ],
            ),
          ),
          // ── Floating input bar ────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildInputBar(state.isLoading, isDark),
          ),
          // ── Jump-to-bottom FAB ────────────────────────────────
          if (_smartScroll.showJumpFab)
            Positioned(
              right: 16,
              bottom: 110,
              child: _JumpFab(onTap: _smartScroll.jumpToBottom, isDark: isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildList(ChatState state, bool isDark) {
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

  Widget _buildThinkingBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: isDark ? AppColors.primaryDark : AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI 正在思考…',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => ref
                .read(chatProvider(widget.conversationId).notifier)
                .stopGeneration(),
            child: Row(
              children: [
                Icon(Icons.stop_circle_outlined,
                    size: 13, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  '停止',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.error,
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

  Future<void> _handleCamera() async {
    final service = ref.read(imageInputServiceProvider);
    final img = await service.pickFromCamera();
    if (img == null || !mounted) return;
    ref
        .read(chatProvider(widget.conversationId).notifier)
        .addPendingImage(img);
  }

  Widget _buildInputBar(bool isLoading, bool isDark) {
    final pendingImages = ref.watch(
        chatProvider(widget.conversationId).select((s) => s.pendingImages));
    final hasText = _input.text.trim().isNotEmpty;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? AppColors.bgPageDark : AppColors.bgPage)
                .withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.dividerDark : AppColors.divider,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
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
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Attach
                      _InputIcon(
                        icon: Icons.attach_file,
                        tooltip: '附加图片',
                        isDark: isDark,
                        onTap: isLoading
                            ? null
                            : () => _showImagePicker(context),
                      ),
                      // Camera — mobile only
                      if (!kIsWeb &&
                          (defaultTargetPlatform == TargetPlatform.iOS ||
                              defaultTargetPlatform == TargetPlatform.android))
                        _InputIcon(
                          icon: Icons.camera_alt_outlined,
                          tooltip: '拍照',
                          isDark: isDark,
                          onTap: isLoading ? null : _handleCamera,
                        ),
                      const SizedBox(width: 4),
                      // Text field
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _inputFocus,
                          enabled: !isLoading,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSend(),
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: isLoading ? '等待回复中…' : '向 PathPocket 提问',
                            hintStyle: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiary,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.bgInputDark
                                : AppColors.bgInput,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.bubble),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.dividerDark
                                    : AppColors.divider,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.bubble),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.dividerDark
                                    : AppColors.divider,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.bubble),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Voice — right of input, left of send
                      VoiceInputButton(controller: _input),
                      const SizedBox(width: 6),
                      _SendButton(
                        isLoading: isLoading,
                        hasText: hasText || pendingImages.isNotEmpty,
                        isDark: isDark,
                        onTap: _handleSend,
                      ),
                    ],
                  ),
                ),
                // Disclaimer
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'PathPocket 可能会出错，注意核实重要信息',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Input icon button ─────────────────────────────────────────────────────────

class _InputIcon extends StatelessWidget {
  const _InputIcon({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: onTap == null
            ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary)
            : (isDark ? AppColors.primaryDark : AppColors.primary),
        onPressed: onTap,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}

// ── Send button with press animation ─────────────────────────────────────────

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.isLoading,
    required this.hasText,
    required this.isDark,
    required this.onTap,
  });
  final bool isLoading;
  final bool hasText;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDark ? AppColors.primaryDark : AppColors.primary;

    if (widget.isLoading) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        padding: const EdgeInsets.all(10),
        child: const CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: widget.hasText ? color : color.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Jump-to-bottom FAB ────────────────────────────────────────────────────────

class _JumpFab extends StatelessWidget {
  const _JumpFab({required this.onTap, required this.isDark});
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.divider,
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
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Pending image strip ───────────────────────────────────────────────────────

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
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final img = images[i];
          return GestureDetector(
            onTap: () => onTap(img),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.memory(
                    img.bytes,
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => onRemove(img.id),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 11, color: Colors.white),
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

// ── Citation drawer host ──────────────────────────────────────────────────────

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
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          SizedBox(
            width: 320,
            child: _CitationPanel(
              citations: drawerState.citations,
              focusId: drawerState.focus?.citationId,
              onClose: () =>
                  ref.read(citationDrawerProvider.notifier).close(),
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
            onClose: () =>
                ref.read(citationDrawerProvider.notifier).close(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.accentDark : AppColors.accent;

    return Material(
      color: isDark ? AppColors.bgSurfaceDark : AppColors.bgSurface,
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '参考文献',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiary,
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.dividerDark : AppColors.divider,
          ),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: citations.length,
              separatorBuilder: (_, __) => Divider(
                height: 16,
                color: isDark ? AppColors.dividerDark : AppColors.divider,
              ),
              itemBuilder: (_, i) {
                final c = citations[i];
                final isFocused = c.id == focusId;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? (isDark
                            ? AppColors.primaryContainerDark
                            : AppColors.primaryContainer)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: isFocused
                        ? Border.all(
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primary,
                            width: 1,
                          )
                        : null,
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
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.title,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.snippet,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          height: 1.5,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (c.source != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            c.source!,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiary,
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
