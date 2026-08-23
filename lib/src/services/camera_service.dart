import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Owns the [CameraController] lifecycle and exposes only manual controls.
///
/// Autofocus is deliberately parked in [FocusMode.locked] so the picture never
/// hunts on its own; focus and metering move only when the user taps the
/// viewfinder. Zoom is likewise driven exclusively from the rocker buttons.
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _cameraIndex = 0;

  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;

  double _minExposure = 0;
  double _maxExposure = 0;
  double _exposure = 0;

  FlashMode _flashMode = FlashMode.off;
  bool _isBusy = false;
  String? _errorMessage;

  /// Preview quality. 720p keeps the GPU cost of the tape shader low while
  /// still giving the emulation more detail than a real VHS master had.
  static const ResolutionPreset _preset = ResolutionPreset.high;

  CameraController? get controller => _controller;
  bool get isReady => _controller?.value.isInitialized ?? false;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;

  bool get hasMultipleCameras => _cameras.length > 1;
  CameraDescription? get description =>
      _cameras.isEmpty ? null : _cameras[_cameraIndex];
  bool get isFrontFacing =>
      description?.lensDirection == CameraLensDirection.front;

  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get zoom => _zoom;
  bool get canZoom => _maxZoom > _minZoom + 0.001;

  double get minExposure => _minExposure;
  double get maxExposure => _maxExposure;
  double get exposure => _exposure;
  bool get canExpose => _maxExposure > _minExposure + 0.001;

  FlashMode get flashMode => _flashMode;
  bool get torchOn => _flashMode == FlashMode.torch;

  /// Aspect ratio of the sensor preview expressed as width / height in
  /// portrait orientation.
  double get previewAspectRatio {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) return 3 / 4;
    return 1 / c.value.aspectRatio;
  }

  Future<void> initialize() async {
    if (_isBusy) return;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        _fail('No camera found on this device.');
        return;
      }
      await _bind(_cameraIndex);
    } on CameraException catch (e) {
      _fail(_describe(e));
    } catch (e) {
      _fail('$e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2 || _isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      await _bind((_cameraIndex + 1) % _cameras.length);
    } on CameraException catch (e) {
      _fail(_describe(e));
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _bind(int index) async {
    final CameraController? previous = _controller;
    _controller = null;
    notifyListeners();
    await previous?.dispose();

    _cameraIndex = index;
    final CameraController next = CameraController(
      _cameras[index],
      _preset,
      // Audio is captured separately by the encoder pipeline, so the camera
      // must not hold the microphone.
      enableAudio: false,
    );
    await next.initialize();
    try {
      await _ignoreUnsupported(
        () => next.lockCaptureOrientation(DeviceOrientation.portraitUp),
      );

      _minZoom = await _valueOr(next.getMinZoomLevel, 1.0);
      _maxZoom = await _valueOr(next.getMaxZoomLevel, 1.0);
      if (_maxZoom < _minZoom) _maxZoom = _minZoom;
      _zoom = _minZoom;
      await _ignoreUnsupported(() => next.setZoomLevel(_zoom));

      _minExposure = await _valueOr(next.getMinExposureOffset, 0.0);
      _maxExposure = await _valueOr(next.getMaxExposureOffset, 0.0);
      if (_maxExposure < _minExposure) _maxExposure = _minExposure;
      _exposure = 0;
      await _ignoreUnsupported(() => next.setExposureOffset(0));

      // Fully manual: nothing refocuses or re-meters until the user taps.
      await _ignoreUnsupported(() => next.setFocusMode(FocusMode.locked));
      await _ignoreUnsupported(() => next.setExposureMode(ExposureMode.locked));
      _flashMode = FlashMode.off;
      await _ignoreUnsupported(() => next.setFlashMode(FlashMode.off));
    } catch (_) {
      // Otherwise the native device stays open and every retry reports
      // "camera already in use".
      await next.dispose();
      rethrow;
    }

    _controller = next;
    _errorMessage = null;
    notifyListeners();
  }

  /// Focus + meter at [point], expressed in 0..1 viewfinder coordinates.
  Future<void> focusAt(Offset point) async {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final Offset clamped = Offset(
      point.dx.clamp(0.0, 1.0),
      point.dy.clamp(0.0, 1.0),
    );
    await _ignoreUnsupported(() async {
      await c.setFocusPoint(clamped);
      // A one-shot auto pass converges on the tapped region, then we lock it
      // again so the image stays put.
      await c.setFocusMode(FocusMode.auto);
      await c.setExposurePoint(clamped);
      await c.setExposureMode(ExposureMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await c.setFocusMode(FocusMode.locked);
      await c.setExposureMode(ExposureMode.locked);
    });
  }

  /// Absolute zoom, clamped to the device range.
  Future<void> setZoom(double value) async {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final double next = value.clamp(_minZoom, _maxZoom);
    if ((next - _zoom).abs() < 0.0005) return;
    _zoom = next;
    notifyListeners();
    await _ignoreUnsupported(() => c.setZoomLevel(next));
  }

  /// Relative zoom step used by the press-and-hold rocker.
  Future<void> nudgeZoom(double delta) => setZoom(_zoom + delta);

  Future<void> resetZoom() => setZoom(_minZoom);

  Future<void> setExposureOffset(double value) async {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized || !canExpose) return;
    final double next = value.clamp(_minExposure, _maxExposure);
    if ((next - _exposure).abs() < 0.0005) return;
    _exposure = next;
    notifyListeners();
    await _ignoreUnsupported(() => c.setExposureOffset(next));
  }

  Future<void> toggleTorch() async {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final FlashMode next = torchOn ? FlashMode.off : FlashMode.torch;
    final bool ok = await _ignoreUnsupported(() => c.setFlashMode(next));
    if (ok) {
      _flashMode = next;
      notifyListeners();
    }
  }

  /// Releases the sensor when backgrounded and restores it on resume.
  Future<void> handleLifecycle(AppLifecycleState state) async {
    final CameraController? c = _controller;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (c == null) return;
        _controller = null;
        notifyListeners();
        await c.dispose();
      case AppLifecycleState.resumed:
        if (c == null) await initialize();
    }
  }

  void _fail(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  static String _describe(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera permission denied. Enable it in system settings.';
      default:
        return e.description ?? e.code;
    }
  }

  /// Runs [action], swallowing the "not supported on this device" family of
  /// errors that older/cheaper hardware throws for optional controls.
  static Future<bool> _ignoreUnsupported(
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return true;
    } on CameraException catch (e) {
      debugPrint('Camera control unavailable: ${e.code} ${e.description}');
      return false;
    }
  }

  static Future<double> _valueOr(
    Future<double> Function() query,
    double fallback,
  ) async {
    try {
      return await query();
    } on CameraException catch (e) {
      debugPrint('Camera capability unavailable: ${e.code} ${e.description}');
      return fallback;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
