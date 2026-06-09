import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tab_sync_platform_stub.dart'
    if (dart.library.html) 'tab_sync_platform_web.dart' as tab_sync_platform;

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

TabSync createTabSync() =>
    tab_sync_platform.createPlatformTabSync(_NoopTabSync.new) as TabSync;

final tabSyncProvider = Provider<TabSync>((ref) {
  final sync = createTabSync();
  ref.onDispose(sync.dispose);
  return sync;
});
