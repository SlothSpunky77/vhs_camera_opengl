import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhs_camera/src/ui/preview_geometry.dart';

void main() {
  group('PreviewGeometry.toSensor', () {
    test('centre of the window maps to the centre of the sensor', () {
      const PreviewGeometry geometry = PreviewGeometry(
        window: Size(300, 400),
        sourceAspect: 0.75,
      );
      expect(geometry.toSensor(const Offset(150, 200)), const Offset(0.5, 0.5));
    });

    test('crops the sides when the source is wider than the window', () {
      // A landscape sensor (1.5) shown in a 3:4 window: the sides are cut.
      const PreviewGeometry geometry = PreviewGeometry(
        window: Size(300, 400),
        sourceAspect: 1.5,
      );
      final Offset left = geometry.toSensor(const Offset(0, 200));
      expect(left.dy, closeTo(0.5, 1e-6));
      expect(left.dx, closeTo(0.25, 1e-6));
    });

    test('crops top and bottom when the source is taller than the window', () {
      // A 3:4 sensor shown in a 4:3 window: the top and bottom are cut.
      const PreviewGeometry geometry = PreviewGeometry(
        window: Size(400, 300),
        sourceAspect: 0.75,
      );
      final Offset top = geometry.toSensor(const Offset(200, 0));
      expect(top.dx, closeTo(0.5, 1e-6));
      expect(top.dy, closeTo(0.21875, 1e-6));
    });

    test('clamps taps that land outside the window', () {
      const PreviewGeometry geometry = PreviewGeometry(
        window: Size(300, 400),
        sourceAspect: 0.75,
      );
      final Offset out = geometry.toSensor(const Offset(-40, 900));
      expect(out.dx, inInclusiveRange(0, 1));
      expect(out.dy, inInclusiveRange(0, 1));
    });

    test('degrades gracefully for an unmeasured window', () {
      const PreviewGeometry geometry = PreviewGeometry(
        window: Size.zero,
        sourceAspect: 0.75,
      );
      expect(geometry.toSensor(Offset.zero), const Offset(0.5, 0.5));
    });
  });
}
