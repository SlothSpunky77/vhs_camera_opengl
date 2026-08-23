import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import '../../models/vhs_settings.dart';
import '../../services/vhs_shader.dart';

/// Paints [child] through the VHS fragment shader, every frame.
///
/// The animation clock is published through a [ValueNotifier] instead of
/// [State.setState] so the camera preview subtree underneath is never rebuilt -
/// only repainted. That is the difference between a smooth 60fps viewfinder and
/// a stuttering one on entry level hardware.
class VhsViewfinder extends StatefulWidget {
  const VhsViewfinder({
    required this.shader,
    required this.settings,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final VhsShader shader;
  final VhsSettings settings;
  final Widget child;
  final bool enabled;

  @override
  State<VhsViewfinder> createState() => _VhsViewfinderState();
}

class _VhsViewfinderState extends State<VhsViewfinder>
    with SingleTickerProviderStateMixin {
  late final ui.FragmentShader _shader = widget.shader.createShader();
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((Duration elapsed) {
      _time.value = VhsShader.wrapTime(elapsed);
    });
    if (widget.enabled) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant VhsViewfinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.enabled && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return ListenableBuilder(
      listenable: _time,
      builder: (BuildContext context, Widget? child) {
        return AnimatedSampler((ui.Image image, Size size, Canvas canvas) {
          VhsShader.configure(
            _shader,
            settings: widget.settings,
            size: size,
            time: _time.value,
            image: image,
          );
          canvas.drawRect(Offset.zero & size, Paint()..shader = _shader);
        }, child: child!);
      },
      child: widget.child,
    );
  }
}
