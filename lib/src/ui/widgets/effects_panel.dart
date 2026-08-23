import 'package:flutter/material.dart';

import '../../models/capture_settings.dart';
import '../../models/vhs_settings.dart';
import '../vhs_theme.dart';

/// Bottom sheet exposing every tape parameter plus the capture format.
class EffectsPanel extends StatelessWidget {
  const EffectsPanel({
    required this.settings,
    required this.capture,
    required this.onSettings,
    required this.onCapture,
    required this.recording,
    super.key,
  });

  final VhsSettings settings;
  final CaptureSettings capture;
  final ValueChanged<VhsSettings> onSettings;
  final ValueChanged<CaptureSettings> onCapture;
  final bool recording;

  static Future<void> show(
    BuildContext context, {
    required VhsSettings settings,
    required CaptureSettings capture,
    required ValueChanged<VhsSettings> onSettings,
    required ValueChanged<CaptureSettings> onCapture,
    required bool recording,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: VhsTheme.background,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxHeight: 620),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return EffectsPanel(
              settings: settings,
              capture: capture,
              recording: recording,
              onSettings: (VhsSettings next) {
                setSheetState(() => settings = next);
                onSettings(next);
              },
              onCapture: (CaptureSettings next) {
                setSheetState(() => capture = next);
                onCapture(next);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: <Widget>[
          _heading('TAPE PRESET'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VhsPreset.all.map((VhsPreset preset) {
              final bool selected = preset.settings == settings;
              return GestureDetector(
                onTap: () => onSettings(preset.settings),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? VhsTheme.accent : VhsTheme.panel,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VhsTheme.outline),
                  ),
                  child: Text(
                    preset.name.toUpperCase(),
                    style: VhsTheme.mono(
                      size: 11,
                      color: selected ? VhsTheme.background : VhsTheme.osd,
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 22),
          _heading('RECORDING'),
          const SizedBox(height: 10),
          _ToggleRow(
            label: 'RECORD AUDIO',
            value: capture.recordAudio,
            enabled: !recording,
            onChanged: (bool v) => onCapture(capture.copyWith(recordAudio: v)),
          ),
          _ToggleRow(
            label: 'BURN IN DATE STAMP',
            value: capture.burnInTimestamp,
            onChanged: (bool v) =>
                onCapture(capture.copyWith(burnInTimestamp: v)),
          ),
          const SizedBox(height: 22),
          _heading('SIGNAL'),
          const SizedBox(height: 6),
          _slider(
            'CHROMATIC ABERRATION',
            settings.chromaticShift,
            0,
            1.5,
            (double v) => onSettings(settings.copyWith(chromaticShift: v)),
          ),
          _slider(
            'COLOR BLEED',
            settings.colorBleed,
            0,
            1.2,
            (double v) => onSettings(settings.copyWith(colorBleed: v)),
          ),
          _slider(
            'GHOSTING',
            settings.ghosting,
            0,
            1,
            (double v) => onSettings(settings.copyWith(ghosting: v)),
          ),
          _slider(
            'EDGE RINGING',
            settings.sharpen,
            0,
            1.2,
            (double v) => onSettings(settings.copyWith(sharpen: v)),
          ),
          const SizedBox(height: 16),
          _heading('TAPE WEAR'),
          const SizedBox(height: 6),
          _slider(
            'NOISE + DROPOUTS',
            settings.noise,
            0,
            1,
            (double v) => onSettings(settings.copyWith(noise: v)),
          ),
          _slider(
            'TRACKING',
            settings.tracking,
            0,
            1,
            (double v) => onSettings(settings.copyWith(tracking: v)),
          ),
          _slider(
            'TRANSPORT WARP',
            settings.warp,
            0,
            1.2,
            (double v) => onSettings(settings.copyWith(warp: v)),
          ),
          _slider(
            'TAPE LINES',
            settings.tapeLines,
            140,
            720,
            (double v) => onSettings(settings.copyWith(tapeLines: v)),
            format: (double v) => v.round().toString(),
          ),
          const SizedBox(height: 16),
          _heading('OPTICS'),
          const SizedBox(height: 6),
          _slider(
            'SCANLINES',
            settings.scanlines,
            0,
            1,
            (double v) => onSettings(settings.copyWith(scanlines: v)),
          ),
          _slider(
            'LENS CURVATURE',
            settings.curvature,
            0,
            1.2,
            (double v) => onSettings(settings.copyWith(curvature: v)),
          ),
          _slider(
            'VIGNETTE',
            settings.vignette,
            0,
            1,
            (double v) => onSettings(settings.copyWith(vignette: v)),
          ),
          _slider(
            'HALATION',
            settings.bloom,
            0,
            1,
            (double v) => onSettings(settings.copyWith(bloom: v)),
          ),
          const SizedBox(height: 16),
          _heading('GRADE'),
          const SizedBox(height: 6),
          _slider(
            'SATURATION',
            settings.saturation,
            0,
            2,
            (double v) => onSettings(settings.copyWith(saturation: v)),
          ),
          _slider(
            'CONTRAST',
            settings.contrast,
            0.6,
            1.6,
            (double v) => onSettings(settings.copyWith(contrast: v)),
          ),
          _slider(
            'BRIGHTNESS',
            settings.brightness,
            -0.2,
            0.2,
            (double v) => onSettings(settings.copyWith(brightness: v)),
          ),
          _slider(
            'TINT  GREEN <> MAGENTA',
            settings.tint,
            -1,
            1,
            (double v) => onSettings(settings.copyWith(tint: v)),
          ),
        ],
      ),
    );
  }

  static Widget _heading(String text) => Text(
    text,
    style: VhsTheme.mono(size: 11, color: VhsTheme.accent, spacing: 2.4),
  );

  static Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String Function(double)? format,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label, style: VhsTheme.mono(size: 10, spacing: 1.6)),
              Text(
                (format ?? (double v) => v.toStringAsFixed(2))(value),
                style: VhsTheme.mono(size: 10, color: VhsTheme.amber),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: VhsTheme.mono(size: 11, spacing: 1.6)),
          Switch(
            value: value,
            activeThumbColor: VhsTheme.accent,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
