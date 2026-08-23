import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Reads pixels back off a [RepaintBoundary].
///
/// This is what makes the filter WYSIWYG: photos and videos are literally the
/// composited viewfinder, so the tape emulation, framing and burnt-in OSD are
/// identical to what the user saw.
class FrameCapture {
  const FrameCapture(this.boundaryKey);

  final GlobalKey boundaryKey;

  RenderRepaintBoundary? get _boundary =>
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

  /// Logical size of the captured area, or null when it is not laid out yet.
  Size? get size {
    final RenderRepaintBoundary? b = _boundary;
    return (b != null && b.hasSize) ? b.size : null;
  }

  /// Grabs the viewfinder as tightly packed RGBA of exactly [width] x [height].
  ///
  /// The encoder asserts on the byte count, so the result is rescaled through
  /// a second pass whenever device pixel rounding lands off by a pixel.
  Future<Uint8List?> captureRgba(int width, int height) async {
    final RenderRepaintBoundary? boundary = _boundary;
    if (boundary == null || !boundary.hasSize) return null;
    if (boundary.debugNeedsPaint) {
      await SchedulerBinding.instance.endOfFrame;
      if (_boundary?.debugNeedsPaint ?? true) return null;
    }

    final double pixelRatio = width / boundary.size.width;
    final ui.Image source = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final ui.Image exact = (source.width == width && source.height == height)
          ? source
          : await _resize(source, width, height);
      try {
        final ByteData? data = await exact.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        return data?.buffer.asUint8List();
      } finally {
        if (!identical(exact, source)) exact.dispose();
      }
    } finally {
      source.dispose();
    }
  }

  /// Grabs the viewfinder as PNG bytes ready for the gallery.
  Future<Uint8List?> capturePng({double pixelRatio = 1}) async {
    final RenderRepaintBoundary? boundary = _boundary;
    if (boundary == null || !boundary.hasSize) return null;
    if (boundary.debugNeedsPaint) {
      await SchedulerBinding.instance.endOfFrame;
      if (_boundary?.debugNeedsPaint ?? true) return null;
    }

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static Future<ui.Image> _resize(ui.Image source, int width, int height) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    final ui.Picture picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }
}
