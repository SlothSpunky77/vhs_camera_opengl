import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../vhs_theme.dart';

/// A manual -/+ rocker with press-and-hold ramping.
///
/// Everything on this camera is manual by design, so the rocker is the only way
/// to move zoom or exposure. Holding accelerates smoothly and releasing stops
/// immediately - there is no timer left running behind the user's back.
class HoldRocker extends StatefulWidget {
  const HoldRocker({
    required this.label,
    required this.readout,
    required this.onDelta,
    this.unitsPerSecond = 1.0,
    this.accelerate = true,
    this.enabled = true,
    this.onReset,
    super.key,
  });

  /// Short caption, e.g. `ZOOM`.
  final String label;

  /// Current value rendered between the buttons, e.g. `2.4x`.
  final String readout;

  /// Called with the signed amount to add, already scaled by elapsed time.
  final ValueChanged<double> onDelta;

  /// Base travel per second while held.
  final double unitsPerSecond;

  /// Whether holding ramps up to 3x speed over two seconds.
  final bool accelerate;

  final bool enabled;

  /// Long-pressing the readout resets the value.
  final VoidCallback? onReset;

  @override
  State<HoldRocker> createState() => _HoldRockerState();
}

class _HoldRockerState extends State<HoldRocker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _spring;

  Duration _last = Duration.zero;
  Duration _heldFor = Duration.zero;
  double _dragOffset = 0.0;
  final double _maxOffset = 30.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _spring = AnimationController.unbounded(vsync: this);
    _spring.addListener(() {
      setState(() {
        _dragOffset = _spring.value;
      });
    });
  }

  void _onTick(Duration elapsed) {
    final Duration dt = elapsed - _last;
    _last = elapsed;
    if (_dragOffset == 0 || dt <= Duration.zero) return;

    _heldFor += dt;

    final double seconds = dt.inMicroseconds / 1000000.0;
    final double ramp = widget.accelerate
        ? 1.0 + 2.0 * (_heldFor.inMilliseconds / 1500.0).clamp(0.0, 1.0)
        : 1.0;

    // Calculate direction and intensity from drag offset.
    // Negative offset means dragging up (which increases the value, so direction = 1).
    final double intensity = (_dragOffset / _maxOffset).abs();
    final double direction = _dragOffset < 0 ? 1 : -1;

    widget.onDelta(direction * intensity * widget.unitsPerSecond * ramp * seconds);
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _spring.stop();
    if (_ticker.isActive) _ticker.stop();
    _last = Duration.zero;
    _heldFor = Duration.zero;
    _ticker.start();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(-_maxOffset, _maxOffset);
    });
  }

  void _onDragEnd() {
    if (_ticker.isActive) _ticker.stop();
    _spring.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 200, damping: 15),
        _dragOffset,
        0,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double opacity = widget.enabled ? 1 : 0.35;
    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            widget.label,
            style: VhsTheme.mono(size: 9, color: VhsTheme.outline, spacing: 2),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onLongPress: widget.onReset,
            child: Text(
              widget.readout,
              textAlign: TextAlign.center,
              style: VhsTheme.mono(size: 13, color: VhsTheme.accent),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _maxOffset * 2 + 50, // Gap above and below for slider travel
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _onDragStart,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: (_) => _onDragEnd(),
                  onVerticalDragCancel: _onDragEnd,
                  child: Transform.translate(
                    offset: Offset(0, _dragOffset),
                    child: Image.asset(
                      'assets/slider.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
