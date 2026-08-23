import 'package:flutter/material.dart';

import '../../services/camera_service.dart';
import '../../utils/formatting.dart';
import 'hold_rocker.dart';

/// Manual optical/digital zoom rocker bound to [CameraService].
class HoldRockerZoom extends StatelessWidget {
  const HoldRockerZoom({required this.camera, super.key});

  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: camera,
      builder: (BuildContext context, _) {
        // Travel the whole range in roughly four seconds at base speed.
        final double span = camera.maxZoom - camera.minZoom;
        return HoldRocker(
          label: 'ZOOM',
          readout: formatZoom(camera.zoom),
          enabled: camera.canZoom,
          unitsPerSecond: span <= 0 ? 1 : span / 4,
          onDelta: (double delta) => camera.nudgeZoom(delta),
          onReset: camera.resetZoom,
        );
      },
    );
  }
}

/// Manual exposure compensation rocker bound to [CameraService].
class HoldRockerExposure extends StatelessWidget {
  const HoldRockerExposure({required this.camera, super.key});

  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: camera,
      builder: (BuildContext context, _) {
        final double span = camera.maxExposure - camera.minExposure;
        return HoldRocker(
          label: 'EXPOSURE',
          readout: formatExposure(camera.exposure),
          enabled: camera.canExpose,
          accelerate: false,
          unitsPerSecond: span <= 0 ? 1 : span / 3,
          onDelta: (double delta) =>
              camera.setExposureOffset(camera.exposure + delta),
          onReset: () => camera.setExposureOffset(0),
        );
      },
    );
  }
}
