import 'package:flutter/material.dart';

import '../../models/capture_settings.dart';
import '../vhs_theme.dart';

/// A button that uses custom asset images for on/off states.
/// The image switches only when the finger is lifted (onTapUp).
class AssetButton extends StatefulWidget {
  const AssetButton({
    required this.onImage,
    required this.offImage,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    super.key,
  });

  final String onImage;
  final String offImage;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;

  @override
  State<AssetButton> createState() => _AssetButtonState();
}

class _AssetButtonState extends State<AssetButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.35,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            if (widget.enabled) {
              setState(() => _pressed = true);
            }
          },
          onTapUp: (_) {
            if (widget.enabled) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          },
          onTapCancel: () {
            if (widget.enabled) {
              setState(() => _pressed = false);
            }
          },
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: _pressed ? 0.3 : 0.0),
              BlendMode.darken,
            ),
            child: Image.asset(
              widget.active ? widget.onImage : widget.offImage,
              width: 46,
              height: 46,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// The big manual shutter / record trigger.
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    required this.mode,
    required this.recording,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final CaptureMode mode;
  final bool recording;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isVideo = mode == CaptureMode.video;
    final Color ring = recording ? VhsTheme.record : VhsTheme.osd;

    return Semantics(
      button: true,
      label: isVideo
          ? (recording ? 'Stop recording' : 'Start recording')
          : 'Take photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onPressed,
        child: SizedBox(
          width: 86,
          height: 86,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 3),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: recording ? 34 : 64,
                height: recording ? 34 : 64,
                decoration: BoxDecoration(
                  color: isVideo ? VhsTheme.record : VhsTheme.osd,
                  borderRadius: BorderRadius.circular(recording ? 6 : 40),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 82,
                  height: 82,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VhsTheme.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PHOTO / VIDEO selector.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    required this.mode,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final CaptureMode mode;
  final ValueChanged<CaptureMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VhsTheme.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VhsTheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: CaptureMode.values
              .map((CaptureMode value) {
                final bool selected = value == mode;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled && !selected ? () => onChanged(value) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? VhsTheme.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      value == CaptureMode.photo ? 'PHOTO' : 'VIDEO',
                      style: VhsTheme.mono(
                        size: 11,
                        color: selected ? VhsTheme.background : VhsTheme.osd,
                        spacing: 2,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

/// Small square chrome button used around the deck and status strip.
class DeckButton extends StatelessWidget {
  const DeckButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: active ? VhsTheme.accent : VhsTheme.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: VhsTheme.outline),
            ),
            child: Icon(
              icon,
              size: 21,
              color: active ? VhsTheme.background : VhsTheme.osd,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable text chip that cycles through an enum-style setting.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.value,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final String value;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: VhsTheme.panel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: highlighted ? VhsTheme.accent : VhsTheme.outline,
          ),
        ),
        child: Text(
          value,
          style: VhsTheme.mono(
            size: 10,
            color: highlighted ? VhsTheme.accent : VhsTheme.osd,
            spacing: 1.6,
          ),
        ),
      ),
    );
  }
}
