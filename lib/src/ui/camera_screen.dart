import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../models/capture_settings.dart';
import '../models/vhs_settings.dart';
import '../services/camera_service.dart';
import '../services/frame_capture.dart';
import '../services/media_store.dart';
import '../services/vhs_shader.dart';
import '../services/vhs_video_recorder.dart';
import '../utils/formatting.dart';
import 'preview_geometry.dart';
import 'vhs_theme.dart';
import 'widgets/deck_controls.dart';
import 'widgets/effects_panel.dart';
import 'widgets/focus_reticle.dart';
import 'widgets/tape_osd.dart';
import 'widgets/vhs_viewfinder.dart';
import 'widgets/zoom_exposure_rockers.dart';

/// The whole camcorder: viewfinder, manual controls and capture pipeline.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final CameraService _camera = CameraService();
  final GlobalKey _tapeKey = GlobalKey();
  final MediaStore _store = const MediaStore();

  late final FrameCapture _frames = FrameCapture(_tapeKey);
  late final VhsVideoRecorder _recorder = VhsVideoRecorder(
    capture: _frames,
    onFailure: _onRecorderFailure,
  );

  VhsShader? _shader;
  String? _shaderError;

  VhsSettings _look = VhsPreset.all[1].settings;
  CaptureSettings _capture = const CaptureSettings();
  CaptureMode _mode = CaptureMode.video;

  Offset? _focusPoint;
  Timer? _focusTimer;
  String? _message;
  Timer? _messageTimer;
  bool _busy = false;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera.addListener(_onCameraChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final VhsShader shader = await VhsShader.load();
      if (!mounted) return;
      setState(() => _shader = shader);
    } catch (e) {
      if (!mounted) return;
      setState(() => _shaderError = '$e');
    }
    await _camera.initialize();
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed && _recorder.isRecording.value) {
      unawaited(_stopRecording());
    }
    unawaited(_camera.handleLifecycle(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _messageTimer?.cancel();
    _camera.removeListener(_onCameraChanged);
    unawaited(_recorder.dispose());
    _camera.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  void _notify(String message) {
    _messageTimer?.cancel();
    if (!mounted) return;
    setState(() => _message = message);
    _messageTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _handleFocusTap(Offset local, Size window) {
    if (!_camera.isReady) return;
    final PreviewGeometry geometry = PreviewGeometry(
      window: window,
      sourceAspect: _camera.previewAspectRatio,
    );
    unawaited(_camera.focusAt(geometry.toSensor(local)));

    _focusTimer?.cancel();
    setState(() => _focusPoint = local);
    _focusTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  Future<void> _onShutter() async {
    if (_busy) return;
    if (_mode == CaptureMode.photo) {
      await _takePhoto();
    } else if (_recorder.isRecording.value) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _takePhoto() async {
    setState(() {
      _busy = true;
      _flash = true;
    });
    try {
      final double ratio = MediaQuery.devicePixelRatioOf(
        context,
      ).clamp(1.0, 3.0);
      final Uint8List? png = await _frames.capturePng(pixelRatio: ratio);
      if (png == null) {
        _notify('CAPTURE FAILED');
        return;
      }
      final SaveResult result = await _store.savePhoto(png);
      _notify(result.message);
    } catch (e) {
      _notify('CAPTURE FAILED');
      debugPrint('Photo capture failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      Timer(const Duration(milliseconds: 110), () {
        if (mounted) setState(() => _flash = false);
      });
    }
  }

  Future<void> _startRecording() async {
    if (_recorder.isRecording.value) return;
    setState(() => _busy = true);
    try {
      if (!await _store.ensureAccess()) {
        _notify('GALLERY ACCESS DENIED');
        return;
      }
      await _recorder.start(_capture);
    } catch (e) {
      debugPrint('Recorder start failed: $e');
      _notify('ENCODER UNAVAILABLE');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onRecorderFailure(Object error) {
    if (!mounted || !_recorder.isRecording.value) return;
    _notify('TAPE JAMMED - SAVING');
    unawaited(_stopRecording());
  }

  Future<void> _stopRecording() async {
    if (!_recorder.isRecording.value) return;
    if (mounted) setState(() => _busy = true);
    try {
      final String? path = await _recorder.stop();
      if (path == null) {
        _notify('TAPE WRITE FAILED');
        return;
      }
      final SaveResult result = await _store.saveVideo(path);
      _notify(result.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEffects() async {
    await EffectsPanel.show(
      context,
      settings: _look,
      capture: _capture,
      recording: _recorder.isRecording.value,
      onSettings: (VhsSettings next) => setState(() => _look = next),
      onCapture: (CaptureSettings next) => setState(() => _capture = next),
    );
  }

  Future<void> _openGallery() async {
    try {
      await Gal.open();
    } catch (e) {
      _notify('GALLERY UNAVAILABLE');
    }
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/metal_sheet.png'),
          repeat: ImageRepeat.repeat,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _statusBar(),
              Expanded(child: Center(child: _viewfinder())),
              _deck(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBar() {
    final bool recording = _recorder.isRecording.value;
    final String presetName = VhsPreset.all
        .firstWhere(
          (VhsPreset p) => p.settings == _look,
          orElse: () => const VhsPreset('CUSTOM', VhsSettings()),
        )
        .name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  StatusChip(
                    value: presetName.toUpperCase(),
                    highlighted: true,
                    onTap: _openEffects,
                  ),
                  const SizedBox(width: 6),
                  StatusChip(
                    value: _capture.framing.label,
                    onTap: recording
                        ? null
                        : () => setState(
                            () => _capture = _capture.copyWith(
                              framing: _capture.framing.next,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  StatusChip(
                    value: _capture.fps.label,
                    onTap: recording
                        ? null
                        : () => setState(
                            () => _capture = _capture.copyWith(
                              fps: _capture.fps.next,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  StatusChip(
                    value: _capture.resolution.label,
                    onTap: recording
                        ? null
                        : () => setState(
                            () => _capture = _capture.copyWith(
                              resolution: _capture.resolution.next,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AssetButton(
            onImage: 'assets/flashon.png',
            offImage: 'assets/flashoff.png',
            label: 'Toggle light',
            active: _camera.torchOn,
            enabled: _camera.isReady,
            onTap: () => unawaited(_camera.toggleTorch()),
          ),
          const SizedBox(width: 8),
          AssetButton(
            onImage: 'assets/rotateon.png',
            offImage: 'assets/rotateoff.png',
            label: 'Switch camera',
            enabled:
                _camera.hasMultipleCameras && !recording && !_camera.isBusy,
            onTap: () => unawaited(_camera.switchCamera()),
          ),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    return AspectRatio(
      aspectRatio: 1 / _capture.framing.ratio,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size window = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails details) =>
                _handleFocusTap(details.localPosition, window),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                RepaintBoundary(key: _tapeKey, child: _tapeSurface()),
                if (_focusPoint != null)
                  FocusReticle(
                    key: ValueKey<Offset>(_focusPoint!),
                    position: _focusPoint!,
                  ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _flash ? 1 : 0,
                    duration: const Duration(milliseconds: 90),
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
                if (_message != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text(
                            _message!,
                            style: VhsTheme.mono(size: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tapeSurface() {
    final VhsShader? shader = _shader;
    final CameraController? controller = _camera.controller;
    final bool ready = shader != null && _camera.isReady && controller != null;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (ready)
            VhsViewfinder(
              shader: shader,
              settings: _look,
              child: _cameraLayer(controller),
            )
          else
            _placeholder(),
          ValueListenableBuilder<Duration>(
            valueListenable: _recorder.elapsed,
            builder: (BuildContext context, Duration elapsed, _) {
              return TapeOsd(
                showStamp: _capture.burnInTimestamp,
                recording: _recorder.isRecording.value,
                elapsed: elapsed,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cameraLayer(CameraController controller) {
    final double aspect = _camera.previewAspectRatio;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox(
          width: aspect * 1000,
          height: 1000,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _placeholder() {
    final String text = _shaderError != null
        ? 'SHADER ERROR'
        : _camera.errorMessage ?? 'STANDBY';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_shaderError == null && _camera.errorMessage == null)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VhsTheme.accent,
              ),
            ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              text.toUpperCase(),
              textAlign: TextAlign.center,
              style: VhsTheme.mono(size: 11, color: VhsTheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deck() {
    final bool recording = _recorder.isRecording.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              HoldRockerZoom(camera: _camera),
              HoldRockerExposure(camera: _camera),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              AssetButton(
                onImage: 'assets/settings.png',
                offImage: 'assets/settings.png',
                label: 'Tape settings',
                onTap: () => unawaited(_openEffects()),
              ),
              ShutterButton(
                mode: _mode,
                recording: recording,
                busy: _busy,
                onPressed: () => unawaited(_onShutter()),
              ),
              AssetButton(
                onImage: 'assets/gallery.png',
                offImage: 'assets/gallery.png',
                label: 'Open gallery',
                onTap: () => unawaited(_openGallery()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<Duration>(
            valueListenable: _recorder.elapsed,
            builder: (BuildContext context, Duration elapsed, _) {
              if (!recording) {
                return ModeSelector(
                  mode: _mode,
                  enabled: !_busy,
                  onChanged: (CaptureMode next) => setState(() => _mode = next),
                );
              }
              return Text(
                'REC  ${formatTimecode(elapsed)}',
                style: VhsTheme.mono(size: 13, color: VhsTheme.record),
              );
            },
          ),
        ],
      ),
    );
  }
}
