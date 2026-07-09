import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('pathpocketInitOSD')
external void _pathpocketInitOSD(
    String elementId, String dziUrl, String tileBase, String token);

final Set<String> _registered = {};

/// Web viewer: registers an HtmlElementView factory that creates a host div and
/// kicks off OpenSeadragon (via the pathpocket_osd.js glue) once it's in the DOM.
Widget buildWsiViewer({
  required String viewType,
  required String dziUrl,
  required String tileBase,
  required String token,
}) {
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = 'osd-$viewType-$id';
      div.style.width = '100%';
      div.style.height = '100%';
      div.style.backgroundColor = '#000';
      // OpenSeadragon needs the element in the DOM before init.
      web.window.requestAnimationFrame((double _) {
        _pathpocketInitOSD(div.id, dziUrl, tileBase, token);
      }.toJS);
      return div;
    });
  }
  return HtmlElementView(viewType: viewType);
}
