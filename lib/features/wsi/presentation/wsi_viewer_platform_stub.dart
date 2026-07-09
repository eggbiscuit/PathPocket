import 'package:flutter/material.dart';

/// Non-web fallback: OpenSeadragon requires HtmlElementView, so the viewer is
/// web-only for now.
Widget buildWsiViewer({
  required String viewType,
  required String dziUrl,
  required String tileBase,
  required String token,
}) {
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'WSI 切片预览目前仅支持 Web 端。',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 15),
      ),
    ),
  );
}
