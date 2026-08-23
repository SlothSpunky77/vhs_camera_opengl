import 'package:flutter_test/flutter_test.dart';
import 'package:vhs_camera/src/models/capture_settings.dart';

void main() {
  group('CaptureSettings audio pacing', () {
    test('every frame rate yields a whole number of PCM bytes per frame', () {
      for (final TapeFps fps in TapeFps.values) {
        final CaptureSettings settings = const CaptureSettings().copyWith(
          fps: fps,
        );
        final int bytes = settings.audioBytesPerFrame;

        // flutter_quick_video_encoder asserts on exactly this expression.
        expect(
          bytes,
          (CaptureSettings.sampleRate *
                  CaptureSettings.audioChannels *
                  2 /
                  fps.value)
              .round(),
          reason: '${fps.label} must divide the sample rate evenly',
        );
        expect(bytes.isEven, isTrue, reason: '16-bit samples are 2 bytes');
      }
    });
  });

  group('CaptureSettings bitrate', () {
    test('scales with pixel count and stays inside sane bounds', () {
      const CaptureSettings settings = CaptureSettings();
      final int low = settings.videoBitrateFor(320, 240);
      final int high = settings.videoBitrateFor(1280, 720);

      expect(low, greaterThanOrEqualTo(600000));
      expect(high, lessThanOrEqualTo(12000000));
      expect(high, greaterThan(low));
    });
  });

  group('enum cycling', () {
    test('next wraps around for every cyclable setting', () {
      expect(Framing.values.last.next, Framing.values.first);
      expect(TapeFps.values.last.next, TapeFps.values.first);
      expect(TapeResolution.values.last.next, TapeResolution.values.first);
      expect(Framing.fourThree.next, Framing.sixteenNine);
    });

    test('framing ratios are portrait height/width', () {
      expect(Framing.fourThree.ratio, closeTo(1.333, 0.001));
      expect(Framing.square.ratio, 1);
    });
  });
}
