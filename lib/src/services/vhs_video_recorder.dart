import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';

import '../models/capture_settings.dart';
import 'frame_capture.dart';
import 'media_store.dart';
import 'pcm_microphone_tap.dart';

/// Records the *filtered* viewfinder to an MP4 using the platform H.264
/// encoder (MediaCodec on Android, AVFoundation on iOS).
///
/// The loop is driven by a wall clock rather than by capture speed: if a GPU
/// readback runs long, the previous frame is repeated so the tape never drifts
/// away from the microphone.
class VhsVideoRecorder {
  VhsVideoRecorder({required FrameCapture capture, this.onFailure})
    : _capture = capture;

  final FrameCapture _capture;
  final PcmMicrophoneTap _microphone = PcmMicrophoneTap();

  /// Invoked when the encode loop dies mid-take so the UI can finalise the
  /// tape instead of sitting on a frozen REC counter.
  final void Function(Object error)? onFailure;

  final ValueNotifier<Duration> elapsed = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isRecording = ValueNotifier<bool>(false);

  bool _starting = false;
  bool _stopRequested = false;
  Future<void>? _loop;
  String? _outputPath;
  Uint8List? _lastFrame;

  /// Starts encoding. Throws when the encoder cannot be configured.
  Future<void> start(CaptureSettings settings) async {
    // The encoder is a process-wide singleton, so a second `setup()` would
    // clobber the first session. Guard synchronously: `isRecording` is only
    // set several awaits from here.
    if (_starting || isRecording.value) return;
    _starting = true;
    try {
      await _start(settings);
    } finally {
      _starting = false;
    }
  }

  Future<void> _start(CaptureSettings settings) async {
    final Size? viewfinder = _capture.size;
    if (viewfinder == null || viewfinder.isEmpty) {
      throw StateError('Viewfinder is not laid out yet.');
    }

    final int height = _even(settings.resolution.height);
    final int width = _even(
      (settings.resolution.height * viewfinder.width / viewfinder.height)
          .round(),
    );

    final String path = await MediaStore.newVideoPath();
    final bool audioOn =
        settings.recordAudio ? await _microphone.start() : false;

    try {
      await FlutterQuickVideoEncoder.setLogLevel(LogLevel.error);
      await FlutterQuickVideoEncoder.setup(
        width: width,
        height: height,
        fps: settings.fps.value,
        videoBitrate: settings.videoBitrateFor(width, height),
        profileLevel: ProfileLevel.any,
        // The track is always written; when the mic is unavailable the samples
        // are digital silence. A fixed layout keeps A/V sync trivial.
        audioChannels: CaptureSettings.audioChannels,
        audioBitrate: CaptureSettings.audioBitrate,
        sampleRate: CaptureSettings.sampleRate,
        filepath: path,
      );
    } catch (_) {
      // Never leave the microphone hot when the take never began.
      await _microphone.stop();
      MediaStore.unawaitedDelete(path);
      rethrow;
    }

    _outputPath = path;
    _lastFrame = null;
    _stopRequested = false;
    elapsed.value = Duration.zero;
    isRecording.value = true;

    if (settings.recordAudio && !audioOn) {
      debugPrint('Recording without audio: microphone unavailable.');
    }

    _loop = _run(settings, width, height);
  }

  Future<void> _run(CaptureSettings settings, int width, int height) async {
    final int frameMicros = 1000000 ~/ settings.fps.value;
    final int audioBytes = settings.audioBytesPerFrame;
    // A stall may be absorbed by repeating up to a second of tape; beyond that
    // the take is already broken and blocking longer only makes it worse.
    final int maxCatchUpFrames = settings.fps.value;
    final Stopwatch clock = Stopwatch()..start();
    int framesWritten = 0;

    try {
      while (!_stopRequested) {
        final int wanted = clock.elapsedMicroseconds ~/ frameMicros;
        if (framesWritten > wanted) {
          await Future<void>.delayed(
            Duration(microseconds: frameMicros ~/ 4),
          );
          continue;
        }

        Uint8List? frame;
        try {
          frame = await _capture.captureRgba(width, height);
        } catch (e) {
          debugPrint('Frame capture failed: $e');
        }
        frame ??= _lastFrame;
        if (frame == null) {
          await Future<void>.delayed(const Duration(milliseconds: 8));
          continue;
        }
        _lastFrame = frame;

        // Repeat the frame for every slot the readback missed so one second of
        // wall clock always becomes one second of tape.
        final int deficit = (wanted - framesWritten + 1).clamp(
          1,
          maxCatchUpFrames,
        );
        for (int i = 0; i < deficit && !_stopRequested; i++) {
          await FlutterQuickVideoEncoder.appendVideoFrame(frame);
          await FlutterQuickVideoEncoder.appendAudioFrame(
            _microphone.take(audioBytes),
          );
          framesWritten++;
        }
        elapsed.value = clock.elapsed;
      }
    } catch (e) {
      // Deliberately not rethrown: nothing awaits this future until `stop()`,
      // and an unheard error would be reported as an unhandled async error.
      debugPrint('Encoder loop aborted: $e');
      _stopRequested = true;
      onFailure?.call(e);
    }
  }

  /// Stops the loop and finalises the container.
  ///
  /// Returns the path of the finished MP4, or null when nothing usable was
  /// written.
  Future<String?> stop() async {
    if (!isRecording.value) return null;
    _stopRequested = true;
    try {
      await _loop;
    } catch (_) {
      // The failure has already been logged; still finalise the file below.
    }
    _loop = null;
    isRecording.value = false;
    await _microphone.stop();

    final String? path = _outputPath;
    _outputPath = null;
    _lastFrame = null;
    try {
      await FlutterQuickVideoEncoder.finish();
    } catch (e) {
      debugPrint('Encoder finish failed: $e');
      if (path != null) MediaStore.unawaitedDelete(path);
      return null;
    }
    return path;
  }

  Future<void> dispose() async {
    await stop();
    await _microphone.dispose();
    elapsed.dispose();
    isRecording.dispose();
  }

  static int _even(int value) => value.isEven ? value : value + 1;
}
