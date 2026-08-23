import 'dart:ui' as ui;

import '../models/vhs_settings.dart';

/// Loads and drives `shaders/vhs.frag`.
///
/// A [ui.FragmentShader] is a mutable, GPU-backed object: creating one per
/// frame leaks native memory. We therefore create instances up front and only
/// rewrite their uniforms.
class VhsShader {
  VhsShader._(this._program);

  final ui.FragmentProgram _program;

  static const String assetKey = 'shaders/vhs.frag';

  static Future<VhsShader> load() async {
    final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
      assetKey,
    );
    return VhsShader._(program);
  }

  /// Creates a shader instance owned by the caller.
  ///
  /// The live viewfinder and any offscreen bake must not share one instance,
  /// otherwise they race on uniform state.
  ui.FragmentShader createShader() => _program.fragmentShader();

  /// Writes [settings] into [shader] and binds [image] as the source texture.
  static void configure(
    ui.FragmentShader shader, {
    required VhsSettings settings,
    required ui.Size size,
    required double time,
    required ui.Image image,
  }) {
    final List<double> uniforms = settings.toUniforms(
      width: size.width,
      height: size.height,
      time: time,
    );
    assert(
      uniforms.length == VhsSettings.uniformCount,
      'Uniform list is out of sync with vhs.frag',
    );
    for (int i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }
    shader.setImageSampler(0, image);
  }

  /// Wraps elapsed time so `highp` floats keep sub-frame precision even after
  /// hours of recording.
  static double wrapTime(Duration elapsed) =>
      (elapsed.inMicroseconds % 600000000) / 1000000.0;
}
