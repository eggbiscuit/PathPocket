import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../image_input/data/image_input_service.dart';
import '../../image_input/domain/pending_image.dart';
import '../../image_input/presentation/image_picker_bar.dart';
import '../../image_input/presentation/image_viewer_screen.dart';
import 'chat_provider.dart';
import 'voice_input_button.dart';

/// Floating composer pinned to the bottom of [ChatScreen].
///
/// Owns its own text controller/focus node and talks to the chat notifier
/// directly via [conversationId]; the parent only tells it whether a stream is
/// currently in flight (`isLoading`).
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({
    super.key,
    required this.conversationId,
    required this.isLoading,
  });

  final String conversationId;
  final bool isLoading;

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(chatProvider(widget.conversationId).notifier).sendMessage(text);
    _inputFocus.requestFocus();
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
    ref.read(chatProvider(widget.conversationId).notifier).addPendingImage(result);
  }

  Future<void> _handleCamera() async {
    final service = ref.read(imageInputServiceProvider);
    final img = await service.pickFromCamera();
    if (img == null || !mounted) return;
    ref.read(chatProvider(widget.conversationId).notifier).addPendingImage(img);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isLoading = widget.isLoading;
    final pendingImages = ref.watch(
        chatProvider(widget.conversationId).select((s) => s.pendingImages));
    final hasText = _input.text.trim().isNotEmpty;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: p.bgPage.withValues(alpha: 0.85),
            border: Border(top: BorderSide(color: p.divider)),
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
                      _InputIcon(
                        icon: Icons.attach_file,
                        tooltip: '附加图片',
                        onTap:
                            isLoading ? null : () => _showImagePicker(context),
                      ),
                      if (!kIsWeb &&
                          (defaultTargetPlatform == TargetPlatform.iOS ||
                              defaultTargetPlatform == TargetPlatform.android))
                        _InputIcon(
                          icon: Icons.camera_alt_outlined,
                          tooltip: '拍照',
                          onTap: isLoading ? null : _handleCamera,
                        ),
                      const SizedBox(width: 4),
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
                            color: p.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                isLoading ? '等待回复中…' : '向 PathPocket 提问',
                            hintStyle: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: p.textTertiary,
                            ),
                            filled: true,
                            fillColor: p.bgInput,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.bubble),
                              borderSide: BorderSide(color: p.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.bubble),
                              borderSide: BorderSide(color: p.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.bubble),
                              borderSide:
                                  BorderSide(color: p.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      VoiceInputButton(controller: _input),
                      const SizedBox(width: 6),
                      _SendButton(
                        isLoading: isLoading,
                        hasText: hasText || pendingImages.isNotEmpty,
                        onTap: _handleSend,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'PathPocket 可能会出错，注意核实重要信息',
                    style: AppTextStyles.tiny(context),
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
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: onTap == null ? p.textTertiary : p.primary,
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
    required this.onTap,
  });
  final bool isLoading;
  final bool hasText;
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
    final color = context.palette.primary;

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

// ── Pending image strip ───────────────────────────────────────────────────────

class _PendingImageStrip extends StatelessWidget {
  const _PendingImageStrip({
    required this.images,
    required this.onRemove,
    required this.onTap,
  });

  final List<PendingImage> images;
  final void Function(String id) onRemove;
  final void Function(PendingImage img) onTap;

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
                      child:
                          const Icon(Icons.close, size: 11, color: Colors.white),
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
