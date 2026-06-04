import 'package:flutter/material.dart';

/// Wraps a [ScrollController] to auto-scroll to the bottom while a stream
/// is active, and to pause auto-scroll when the user scrolls up.
///
/// Usage:
/// ```dart
/// final controller = SmartScrollController();
/// // in build: pass controller.scrollController to ListView
/// // on new token: controller.onNewContent()
/// // "back to bottom" FAB: Visibility(visible: controller.showJumpFab, ...)
/// ```
class SmartScrollController extends ChangeNotifier {
  SmartScrollController() {
    _scroll.addListener(_onScroll);
  }

  final ScrollController _scroll = ScrollController();

  bool _userScrolledUp = false;
  bool _showJumpFab = false;

  ScrollController get scrollController => _scroll;
  bool get showJumpFab => _showJumpFab;

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final atBottom =
        pos.pixels >= pos.maxScrollExtent - 80; // 80px tolerance

    if (atBottom) {
      if (_userScrolledUp) {
        _userScrolledUp = false;
        _setFab(false);
      }
    } else {
      if (!_userScrolledUp) {
        _userScrolledUp = true;
        _setFab(true);
      }
    }
  }

  void _setFab(bool value) {
    if (_showJumpFab == value) return;
    _showJumpFab = value;
    notifyListeners();
  }

  /// Call after each new token to auto-scroll if user is not scrolled up.
  void onNewContent() {
    if (_userScrolledUp) return;
    _scrollToBottom(animated: false);
  }

  /// Jump to the bottom immediately (used by "回到最新↓" FAB).
  void jumpToBottom() {
    _userScrolledUp = false;
    _setFab(false);
    _scrollToBottom(animated: true);
  }

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.maxScrollExtent <= 0) return;
      if (animated) {
        _scroll.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(pos.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }
}
