import 'package:flutter/foundation.dart';

/// Every tunable parameter of the tape emulation.
///
/// The field order of [toUniforms] is contractually identical to the uniform
/// declaration order in `shaders/vhs.frag`; changing one without the other
/// silently corrupts the look, so both are covered by unit tests.
@immutable
class VhsSettings {
  const VhsSettings({
    this.chromaticShift = 0.55,
    this.colorBleed = 0.45,
    this.scanlines = 0.35,
    this.noise = 0.30,
    this.tracking = 0.25,
    this.warp = 0.35,
    this.saturation = 1.25,
    this.contrast = 1.10,
    this.brightness = 0.02,
    this.vignette = 0.45,
    this.bloom = 0.35,
    this.tapeLines = 320,
    this.curvature = 0.18,
    this.sharpen = 0.45,
    this.ghosting = 0.30,
    this.tint = 0.10,
  });

  /// RF colour misalignment: splits red and blue horizontally.
  final double chromaticShift;

  /// Chroma sub-sampling smear. The signature VHS "colour runs sideways".
  final double colorBleed;

  /// Scanline darkening plus per-field interlace flicker.
  final double scanlines;

  /// Tape grain and white dropout streaks.
  final double noise;

  /// Drifting tracking band and bottom head-switching tear.
  final double tracking;

  /// Horizontal transport jitter of the whole picture.
  final double warp;

  /// Chroma gain applied in YIQ space.
  final double saturation;

  final double contrast;

  final double brightness;

  final double vignette;

  /// Halation bleeding out of clipped highlights.
  final double bloom;

  /// Vertical resolution the tape can resolve. Lower is more degraded.
  final double tapeLines;

  /// CRT barrel distortion. Doubles as a fisheye lens when pushed.
  final double curvature;

  /// Luma edge ringing, the halo consumer camcorders bake in.
  final double sharpen;

  /// Delay-line echo trailing to the right of hard edges.
  final double ghosting;

  /// -1 pushes green, +1 pushes magenta.
  final double tint;

  /// Number of float uniforms consumed by `vhs.frag`, including `uSize`.
  static const int uniformCount = 19;

  /// Packs the settings in shader uniform order.
  ///
  /// [size] is the draw size in logical pixels and occupies slots 0 and 1;
  /// [time] is expected to be pre-wrapped by the caller to preserve float
  /// precision during long recordings.
  List<double> toUniforms({
    required double width,
    required double height,
    required double time,
  }) {
    return <double>[
      width,
      height,
      time,
      chromaticShift,
      colorBleed,
      scanlines,
      noise,
      tracking,
      warp,
      saturation,
      contrast,
      brightness,
      vignette,
      bloom,
      tapeLines,
      curvature,
      sharpen,
      ghosting,
      tint,
    ];
  }

  VhsSettings copyWith({
    double? chromaticShift,
    double? colorBleed,
    double? scanlines,
    double? noise,
    double? tracking,
    double? warp,
    double? saturation,
    double? contrast,
    double? brightness,
    double? vignette,
    double? bloom,
    double? tapeLines,
    double? curvature,
    double? sharpen,
    double? ghosting,
    double? tint,
  }) {
    return VhsSettings(
      chromaticShift: chromaticShift ?? this.chromaticShift,
      colorBleed: colorBleed ?? this.colorBleed,
      scanlines: scanlines ?? this.scanlines,
      noise: noise ?? this.noise,
      tracking: tracking ?? this.tracking,
      warp: warp ?? this.warp,
      saturation: saturation ?? this.saturation,
      contrast: contrast ?? this.contrast,
      brightness: brightness ?? this.brightness,
      vignette: vignette ?? this.vignette,
      bloom: bloom ?? this.bloom,
      tapeLines: tapeLines ?? this.tapeLines,
      curvature: curvature ?? this.curvature,
      sharpen: sharpen ?? this.sharpen,
      ghosting: ghosting ?? this.ghosting,
      tint: tint ?? this.tint,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VhsSettings &&
        other.chromaticShift == chromaticShift &&
        other.colorBleed == colorBleed &&
        other.scanlines == scanlines &&
        other.noise == noise &&
        other.tracking == tracking &&
        other.warp == warp &&
        other.saturation == saturation &&
        other.contrast == contrast &&
        other.brightness == brightness &&
        other.vignette == vignette &&
        other.bloom == bloom &&
        other.tapeLines == tapeLines &&
        other.curvature == curvature &&
        other.sharpen == sharpen &&
        other.ghosting == ghosting &&
        other.tint == tint;
  }

  @override
  int get hashCode => Object.hash(
    chromaticShift,
    colorBleed,
    scanlines,
    noise,
    tracking,
    warp,
    saturation,
    contrast,
    brightness,
    vignette,
    bloom,
    tapeLines,
    curvature,
    sharpen,
    ghosting,
    tint,
  );
}

/// A named, hand-tuned [VhsSettings] bundle.
@immutable
class VhsPreset {
  const VhsPreset(this.name, this.settings);

  final String name;
  final VhsSettings settings;

  /// Ships in tape-order: cleanest first, most destroyed last.
  static const List<VhsPreset> all = <VhsPreset>[
    VhsPreset(
      'S-VHS',
      VhsSettings(
        chromaticShift: 0.22,
        colorBleed: 0.18,
        scanlines: 0.22,
        noise: 0.12,
        tracking: 0.06,
        warp: 0.12,
        saturation: 1.12,
        contrast: 1.06,
        brightness: 0.01,
        vignette: 0.28,
        bloom: 0.22,
        tapeLines: 480,
        curvature: 0.10,
        sharpen: 0.35,
        ghosting: 0.12,
        tint: 0.04,
      ),
    ),
    VhsPreset('VHS-C \'87', VhsSettings()),
    VhsPreset(
      'Camcorder \'92',
      VhsSettings(
        chromaticShift: 0.70,
        colorBleed: 0.60,
        scanlines: 0.42,
        noise: 0.38,
        tracking: 0.30,
        warp: 0.45,
        saturation: 1.40,
        contrast: 1.16,
        brightness: 0.03,
        vignette: 0.55,
        bloom: 0.50,
        tapeLines: 280,
        curvature: 0.24,
        sharpen: 0.60,
        ghosting: 0.42,
        tint: 0.18,
      ),
    ),
    VhsPreset(
      'Worn Tape',
      VhsSettings(
        chromaticShift: 0.95,
        colorBleed: 0.85,
        scanlines: 0.55,
        noise: 0.62,
        tracking: 0.55,
        warp: 0.70,
        saturation: 1.55,
        contrast: 1.22,
        brightness: 0.05,
        vignette: 0.70,
        bloom: 0.65,
        tapeLines: 220,
        curvature: 0.30,
        sharpen: 0.75,
        ghosting: 0.60,
        tint: -0.22,
      ),
    ),
    VhsPreset(
      'Fisheye Cam',
      VhsSettings(
        chromaticShift: 0.80,
        colorBleed: 0.55,
        scanlines: 0.40,
        noise: 0.35,
        tracking: 0.22,
        warp: 0.35,
        saturation: 1.35,
        contrast: 1.14,
        brightness: 0.02,
        vignette: 0.80,
        bloom: 0.45,
        tapeLines: 300,
        curvature: 0.95,
        sharpen: 0.50,
        ghosting: 0.28,
        tint: 0.08,
      ),
    ),
    VhsPreset(
      'Dead Channel',
      VhsSettings(
        chromaticShift: 1.30,
        colorBleed: 1.00,
        scanlines: 0.70,
        noise: 0.90,
        tracking: 0.90,
        warp: 1.00,
        saturation: 1.70,
        contrast: 1.30,
        brightness: 0.06,
        vignette: 0.85,
        bloom: 0.80,
        tapeLines: 180,
        curvature: 0.40,
        sharpen: 0.90,
        ghosting: 0.85,
        tint: -0.40,
      ),
    ),
  ];
}
