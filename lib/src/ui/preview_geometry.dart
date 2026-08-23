import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

/// Geometry of a `BoxFit.cover` camera preview inside the viewfinder window.
///
/// The sensor preview almost never matches the selected framing, so it is
/// centre-cropped. Focus taps must be mapped back through that crop, otherwise
/// the camera focuses on the wrong part of the scene.
@immutable
class PreviewGeometry {
  const PreviewGeometry({required this.window, required this.sourceAspect});

  /// Size of the visible viewfinder window in logical pixels.
  final Size window;

  /// Width / height of the untransformed camera preview.
  final double sourceAspect;

  /// Converts a tap in window coordinates to normalised sensor coordinates.
  Offset toSensor(Offset local) {
    if (window.isEmpty || sourceAspect <= 0) return const Offset(0.5, 0.5);

    // Cover scale: the source is blown up until it fills both axes.
    final double scale = (window.width / sourceAspect) > window.height
        ? window.width / sourceAspect
        : window.height;
    final double renderedWidth = sourceAspect * scale;
    final double renderedHeight = scale;
    final double offsetX = (renderedWidth - window.width) / 2;
    final double offsetY = (renderedHeight - window.height) / 2;

    return Offset(
      ((local.dx + offsetX) / renderedWidth).clamp(0.0, 1.0),
      ((local.dy + offsetY) / renderedHeight).clamp(0.0, 1.0),
    );
  }
}
