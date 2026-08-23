import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vhs_camera/src/models/vhs_settings.dart';

void main() {
  group('VhsSettings uniforms', () {
    test('packs size, time and every parameter in declaration order', () {
      const VhsSettings settings = VhsSettings();
      final List<double> uniforms = settings.toUniforms(
        width: 320,
        height: 480,
        time: 1.5,
      );

      expect(uniforms.length, VhsSettings.uniformCount);
      expect(uniforms[0], 320);
      expect(uniforms[1], 480);
      expect(uniforms[2], 1.5);
      expect(uniforms[3], settings.chromaticShift);
      expect(uniforms[4], settings.colorBleed);
      expect(uniforms.last, settings.tint);
    });

    test('matches the uniform block declared in shaders/vhs.frag', () {
      // The shader and the Dart model must never drift apart: the shader reads
      // uniforms purely by index.
      final List<String> declared = File('shaders/vhs.frag')
          .readAsLinesSync()
          .map((String line) => line.trim())
          .where(
            (String line) =>
                line.startsWith('uniform ') && !line.contains('sampler2D'),
          )
          .toList(growable: false);

      // vec2 uSize occupies two float slots; every other uniform occupies one.
      int slots = 0;
      for (final String line in declared) {
        slots += line.startsWith('uniform vec2') ? 2 : 1;
      }

      expect(slots, VhsSettings.uniformCount);
      expect(declared.first, startsWith('uniform vec2 uSize'));
      expect(declared[2], startsWith('uniform float uChromaticShift'));
      expect(declared.last, startsWith('uniform float uTint'));
    });
  });

  group('VhsPreset', () {
    test('ships presets with unique names', () {
      final Set<String> names = VhsPreset.all
          .map((VhsPreset p) => p.name)
          .toSet();
      expect(names.length, VhsPreset.all.length);
    });

    test('copyWith only changes the requested field', () {
      const VhsSettings base = VhsSettings();
      final VhsSettings tweaked = base.copyWith(noise: 0.9);

      expect(tweaked.noise, 0.9);
      expect(tweaked.colorBleed, base.colorBleed);
      expect(tweaked, isNot(base));
      expect(base.copyWith(), base);
    });

    test('value equality drives preset selection in the UI', () {
      expect(VhsPreset.all[1].settings, const VhsSettings());
      expect(
        VhsPreset.all[1].settings.hashCode,
        const VhsSettings().hashCode,
      );
    });
  });
}
