import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'tab_sync.dart';

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

TabSync createPlatformTabSync(TabSync Function() _fallbackFactory) =>
    _WebTabSync();
