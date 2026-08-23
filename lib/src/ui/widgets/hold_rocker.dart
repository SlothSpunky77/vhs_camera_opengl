import 'package:flutter/material.dart';
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
  Duration _last = Duration.zero;
  Duration _heldFor = Duration.zero;
  int _direction = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    final Duration dt = elapsed - _last;
    _last = elapsed;
    _heldFor += dt;
    if (_direction == 0 || dt <= Duration.zero) return;

    final double seconds = dt.inMicroseconds / 1000000.0;
    final double ramp = widget.accelerate
        ? 1.0 + 2.0 * (_heldFor.inMilliseconds / 1500.0).clamp(0.0, 1.0)
        : 1.0;
    widget.onDelta(_direction * widget.unitsPerSecond * ramp * seconds);
  }

  void _press(int direction) {
    if (!widget.enabled) return;
    // Both buttons are independent recognisers, so a second finger can land
    // while the ticker is still running; restarting it would throw.
    if (_ticker.isActive) _ticker.stop();
    _direction = direction;
    _last = Duration.zero;
    _heldFor = Duration.zero;
    // One immediate step so a quick tap always does something.
    widget.onDelta(direction * widget.unitsPerSecond * 0.06);
    _ticker.start();
  }

  void _release() {
    _direction = 0;
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
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
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: VhsTheme.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VhsTheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _RockerButton(
                  icon: Icons.remove,
                  semanticLabel: '${widget.label} down',
                  onPress: () => _press(-1),
                  onRelease: _release,
                ),
                GestureDetector(
                  onLongPress: widget.onReset,
                  child: SizedBox(
                    width: 62,
                    child: Text(
                      widget.readout,
                      textAlign: TextAlign.center,
                      style: VhsTheme.mono(size: 13, color: VhsTheme.accent),
                    ),
                  ),
                ),
                _RockerButton(
                  icon: Icons.add,
                  semanticLabel: '${widget.label} up',
                  onPress: () => _press(1),
                  onRelease: _release,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RockerButton extends StatelessWidget {
  const _RockerButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPress,
    required this.onRelease,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPress(),
        onTapUp: (_) => onRelease(),
        onTapCancel: onRelease,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Icon(icon, size: 20, color: VhsTheme.osd),
        ),
      ),
    );
  }
}
