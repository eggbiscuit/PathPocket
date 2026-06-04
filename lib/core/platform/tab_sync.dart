import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

/// Events broadcast across browser tabs.
sealed class TabSyncEvent {
  const TabSyncEvent();
  Map<String, dynamic> toJson();

  static TabSyncEvent? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'userChanged':
        return UserChangedEvent(json['userId'] as String?);
      case 'loggedOut':
        return const LoggedOutEvent();
      default:
        return null;
    }
  }
}

class UserChangedEvent extends TabSyncEvent {
  const UserChangedEvent(this.userId);
  final String? userId;

  @override
  Map<String, dynamic> toJson() => {'type': 'userChanged', 'userId': userId};
}

class LoggedOutEvent extends TabSyncEvent {
  const LoggedOutEvent();

  @override
  Map<String, dynamic> toJson() => {'type': 'loggedOut'};
}

/// Cross-tab coordinator. On web uses [BroadcastChannel]; on other platforms
/// it's a no-op (single-process app means no peers to talk to).
abstract class TabSync {
  Stream<TabSyncEvent> get events;
  void publish(TabSyncEvent event);
  void dispose();
}

class _NoopTabSync implements TabSync {
  @override
  Stream<TabSyncEvent> get events => const Stream.empty();

  @override
  void publish(TabSyncEvent event) {}

  @override
  void dispose() {}
}

class _WebTabSync implements TabSync {
  _WebTabSync() : _channel = web.BroadcastChannel('pathpocket-tab-sync') {
    _channel.onmessage = ((web.MessageEvent e) {
      try {
        final raw = (e.data as Object?)?.toString();
        if (raw == null) return;
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final event = TabSyncEvent.fromJson(json);
        if (event != null) _controller.add(event);
      } catch (_) {
        // swallow malformed messages
      }
    }).toJS;
  }

  final web.BroadcastChannel _channel;
  final StreamController<TabSyncEvent> _controller =
      StreamController<TabSyncEvent>.broadcast();

  @override
  Stream<TabSyncEvent> get events => _controller.stream;

  @override
  void publish(TabSyncEvent event) {
    _channel.postMessage(jsonEncode(event.toJson()).toJS);
  }

  @override
  void dispose() {
    _controller.close();
    _channel.close();
  }
}

TabSync createTabSync() => kIsWeb ? _WebTabSync() : _NoopTabSync();

final tabSyncProvider = Provider<TabSync>((ref) {
  final sync = createTabSync();
  ref.onDispose(sync.dispose);
  return sync;
});
