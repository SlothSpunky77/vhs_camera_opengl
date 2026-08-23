import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../models/capture_settings.dart';

/// Streams 16-bit PCM off the microphone into a FIFO the encoder can drain in
/// exact per-video-frame chunks.
///
/// [take] never blocks and never returns a short buffer: an underrun is padded
/// with digital silence. That keeps audio and video locked to the same frame
/// clock even when the GPU readback stalls.
class PcmMicrophoneTap {
  PcmMicrophoneTap();

  final AudioRecorder _recorder = AudioRecorder();
  final Queue<Uint8List> _chunks = Queue<Uint8List>();
  StreamSubscription<Uint8List>? _subscription;
  int _offset = 0;
  int _buffered = 0;
  bool _active = false;

  bool get isActive => _active;

  /// Attempts to open the microphone. Returns false when permission is denied
  /// or the platform refuses the stream; recording then continues silently.
  Future<bool> start() async {
    if (_active) return true;
    try {
      if (!await _recorder.hasPermission()) return false;
      final Stream<Uint8List> stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: CaptureSettings.sampleRate,
          numChannels: CaptureSettings.audioChannels,
          echoCancel: false,
          noiseSuppress: false,
          autoGain: false,
        ),
      );
      _subscription = stream.listen(
        _onChunk,
        onError: (Object error) => debugPrint('Microphone error: $error'),
        cancelOnError: false,
      );
      _active = true;
      return true;
    } catch (e) {
      debugPrint('Microphone unavailable: $e');
      return false;
    }
  }

  void _onChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;
    // Cap the backlog at roughly two seconds so a stalled consumer cannot grow
    // the heap without bound.
    const int maxBuffered =
        CaptureSettings.sampleRate * CaptureSettings.audioChannels * 2 * 2;
    _chunks.add(chunk);
    _buffered += chunk.length;
    while (_buffered > maxBuffered && _chunks.length > 1) {
      final Uint8List dropped = _chunks.removeFirst();
      _buffered -= dropped.length - _offset;
      _offset = 0;
    }
  }

  /// Pops exactly [byteCount] bytes, zero-padding on underrun.
  Uint8List take(int byteCount) {
    final Uint8List out = Uint8List(byteCount);
    int written = 0;
    while (written < byteCount && _chunks.isNotEmpty) {
      final Uint8List head = _chunks.first;
      final int available = head.length - _offset;
      final int n = available < byteCount - written
          ? available
          : byteCount - written;
      out.setRange(written, written + n, head, _offset);
      written += n;
      _offset += n;
      _buffered -= n;
      if (_offset >= head.length) {
        _chunks.removeFirst();
        _offset = 0;
      }
    }
    return out;
  }

  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder.cancel();
    } catch (e) {
      debugPrint('Microphone stop failed: $e');
    }
    _chunks.clear();
    _offset = 0;
    _buffered = 0;
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
