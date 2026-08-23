import 'package:flutter/foundation.dart';

/// What the shutter button will do.
enum CaptureMode { photo, video }

/// Viewfinder framing. VHS is natively 4:3, which is the default.
enum Framing {
  fourThree(4 / 3, '4:3'),
  sixteenNine(16 / 9, '16:9'),
  square(1, '1:1');

  const Framing(this.ratio, this.label);

  /// Height / width of the *portrait* viewfinder box.
  final double ratio;
  final String label;

  Framing get next => Framing.values[(index + 1) % Framing.values.length];
}

/// Frame rate of the baked video.
///
/// Only rates that divide [VideoQuality.sampleRate] evenly are offered, because
/// the encoder requires exactly `sampleRate * channels * 2 / fps` PCM bytes per
/// appended video frame.
enum TapeFps {
  fps15(15, 'LP 15'),
  fps24(24, 'FILM 24'),
  fps25(25, 'PAL 25'),
  fps30(30, 'SP 30');

  const TapeFps(this.value, this.label);

  final int value;
  final String label;

  TapeFps get next => TapeFps.values[(index + 1) % TapeFps.values.length];
}

/// Vertical resolution of the baked video.
///
/// Deliberately low by default: a real VHS master is ~333x480, and keeping the
/// encode small is what makes per-frame GPU readback viable on cheap phones.
enum TapeResolution {
  sd240(240, 'VHS 240p'),
  sd360(360, 'SP 360p'),
  sd480(480, 'SVHS 480p'),
  hd720(720, 'HD 720p');

  const TapeResolution(this.height, this.label);

  final int height;
  final String label;

  TapeResolution get next =>
      TapeResolution.values[(index + 1) % TapeResolution.values.length];
}

/// Everything about *how* media is captured, as opposed to how it looks.
@immutable
class CaptureSettings {
  const CaptureSettings({
    this.framing = Framing.fourThree,
    this.fps = TapeFps.fps30,
    this.resolution = TapeResolution.sd360,
    this.recordAudio = true,
    this.burnInTimestamp = true,
  });

  final Framing framing;
  final TapeFps fps;
  final TapeResolution resolution;
  final bool recordAudio;

  /// Burns the camcorder OSD clock into photos and videos.
  final bool burnInTimestamp;

  /// Audio sample rate. 48 kHz divides evenly by every [TapeFps].
  static const int sampleRate = 48000;
  static const int audioChannels = 1;
  static const int audioBitrate = 96000;

  /// PCM bytes that must accompany a single video frame.
  int get audioBytesPerFrame =>
      (sampleRate * audioChannels * 2) ~/ fps.value;

  /// Video bitrate scaled to the encode size; generous enough that the encoder
  /// does not add its own blocking on top of the tape artefacts.
  int videoBitrateFor(int width, int height) {
    const double bitsPerPixelPerFrame = 0.14;
    return (width * height * fps.value * bitsPerPixelPerFrame)
        .clamp(600000, 12000000)
        .round();
  }

  CaptureSettings copyWith({
    Framing? framing,
    TapeFps? fps,
    TapeResolution? resolution,
    bool? recordAudio,
    bool? burnInTimestamp,
  }) {
    return CaptureSettings(
      framing: framing ?? this.framing,
      fps: fps ?? this.fps,
      resolution: resolution ?? this.resolution,
      recordAudio: recordAudio ?? this.recordAudio,
      burnInTimestamp: burnInTimestamp ?? this.burnInTimestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CaptureSettings &&
        other.framing == framing &&
        other.fps == fps &&
        other.resolution == resolution &&
        other.recordAudio == recordAudio &&
        other.burnInTimestamp == burnInTimestamp;
  }

  @override
  int get hashCode =>
      Object.hash(framing, fps, resolution, recordAudio, burnInTimestamp);
}
