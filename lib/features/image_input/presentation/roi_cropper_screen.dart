import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Full-screen crop screen. Call via:
/// ```dart
/// final cropped = await Navigator.push<Uint8List>(
///   context,
///   MaterialPageRoute(builder: (_) => RoiCropperScreen(imageBytes: bytes)),
/// );
/// ```
/// Returns the cropped [Uint8List] or null if the user cancelled.
class RoiCropperScreen extends StatefulWidget {
  const RoiCropperScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<RoiCropperScreen> createState() => _RoiCropperScreenState();
}

class _RoiCropperScreenState extends State<RoiCropperScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _crop() {
    if (_cropping) return;
    setState(() => _cropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('选择感兴趣区域 (ROI)'),
        actions: [
          TextButton(
            onPressed: _cropping ? null : _crop,
            child: _cropping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '确认',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _controller,
        onCropped: (result) {
          switch (result) {
            case CropSuccess(:final croppedImage):
              if (mounted) Navigator.pop(context, croppedImage);
            case CropFailure(:final cause):
              if (mounted) {
                setState(() => _cropping = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('裁剪失败：$cause'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
          }
        },
        maskColor: Colors.black54,
        baseColor: Colors.black,
        cornerDotBuilder: (size, edgeAlignment) => const DotControl(
          color: AppColors.primary,
        ),
      ),
    );
  }
}
