import 'package:flutter/widgets.dart';

export 'wsi_viewer_platform_stub.dart'
    if (dart.library.js_interop) 'wsi_viewer_platform_web.dart';

/// Signature implemented by both the web and stub variants. Builds the widget
/// that hosts the OpenSeadragon viewer (web) or a "web only" notice (stub).
typedef WsiViewerBuilder = Widget Function({
  required String viewType,
  required String dziUrl,
  required String tileBase,
  required String token,
});
