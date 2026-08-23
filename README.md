# VHS Camera

A lightweight, fully manual VHS camcorder for Android and iOS, built with Flutter.

The tape emulation runs as a single GPU fragment shader on the live camera
feed, so **what you see in the viewfinder is exactly what gets saved** — chromatic
aberration, chroma bleeding, tracking noise, scanlines and all. Nothing is
post-processed after the fact.

---

## What it does

**Real-time tape emulation** — one fragment shader (`shaders/vhs.frag`) models the
whole VHS signal chain in a single pass:

| Effect | What it emulates |
| --- | --- |
| Chromatic aberration | RF colour misalignment splitting red/blue sideways |
| Colour bleed | Chroma sub-sampling smear in Y'IQ space |
| Ghosting | Delay-line echo trailing hard edges |
| Edge ringing | The sharpening halo consumer camcorders baked in |
| Tracking + head switching | Drifting noise band and the torn strip at frame bottom |
| Transport warp | Per-line horizontal jitter and slow tape wobble |
| Dropouts + grain | White streaks and analogue noise |
| Scanlines + interlace | Line darkening and per-field flicker |
| Line quantisation | The tape's real (low) resolution limit |
| Halation, vignette, curvature | CRT glass, barrel distortion, highlight glow |
| Grade | Lifted blacks, tape tint, saturation and contrast |

**Six presets** — `S-VHS`, `VHS-C '87`, `Camcorder '92`, `Worn Tape`,
`Fisheye Cam`, `Dead Channel` — plus 16 live sliders if you want to build your own.

**Everything is manual.**

- **Zoom** — hold the `−`/`+` rocker; it ramps smoothly and stops the instant you
  let go. Long-press the readout to snap back to 1.0x.
- **Focus** — the sensor is parked in locked focus, so the picture never hunts on
  its own. It refocuses and re-meters **only** where you tap the viewfinder.
- **Exposure** — its own rocker, long-press to reset to 0 EV.
- **Torch, lens flip, framing (4:3 / 16:9 / 1:1), frame rate and tape resolution**
  are all one tap away in the status strip.

**Photos and video, both filtered.** Photos are PNGs of the composited viewfinder.
Videos are encoded live through the platform H.264 encoder (MediaCodec on Android,
AVFoundation on iOS) with microphone audio, and land in a `VHS Camera` album in
your gallery.

---

## Requirements

- **Flutter 3.38 or newer** (Dart 3.10+) — <https://docs.flutter.dev/get-started/install>
- **A physical phone.** Emulators and simulators have no usable camera and, on
  Android, no hardware H.264 encoder. The app will not work on them.
- **Android 7.0 (API 24) or newer**, or **iOS 13 or newer**.
- To build for Android you also need the **Android SDK** and a **JDK 17+**
  (both come with Android Studio). To build for iOS you need **Xcode** on macOS.

---

## Running it

```bash
git clone https://github.com/SlothSpunky77/vhs_camera_opengl.git
cd vhs_camera_opengl
flutter pub get

# plug in a phone with USB debugging (Android) or developer mode (iOS) on
flutter devices
flutter run --release
```

`--release` is strongly recommended: debug builds run the shader without
optimisations and the viewfinder will feel sluggish.

Grant the **camera**, **microphone** and **photos** permissions when prompted —
they are requested lazily, the first time each one is needed.

### Building a shippable artifact

```bash
flutter build apk --release          # Android APK
flutter build appbundle --release    # Google Play bundle
flutter build ios --release          # iOS (then archive in Xcode)
```

Android release builds are currently signed with the debug key (see
`android/app/build.gradle.kts`); add your own signing config before publishing.

### Tests and analysis

```bash
flutter analyze
flutter test
```

---

## How it works

```
lib/
  main.dart                     entry point, portrait lock, system chrome
  src/
    app.dart                    MaterialApp + theme
    models/
      vhs_settings.dart         the 16 look parameters + presets
      capture_settings.dart     framing, fps, tape resolution, audio
    services/
      vhs_shader.dart           FragmentProgram loading + uniform packing
      camera_service.dart       CameraController lifecycle, manual controls
      frame_capture.dart        RepaintBoundary -> RGBA / PNG readback
      pcm_microphone_tap.dart   raw PCM mic stream, frame-aligned FIFO
      vhs_video_recorder.dart   wall-clock encode loop
      media_store.dart          gallery writes
    ui/
      camera_screen.dart        the camcorder
      preview_geometry.dart     maps focus taps through the cover-crop
      widgets/                  viewfinder, rockers, OSD, shutter, panel
    utils/formatting.dart       timecode and OSD formatting
shaders/vhs.frag                the tape emulation
```

Three design decisions are worth calling out:

**The shader is one pass.** Multi-pass bloom/blur chains are what make retro
camera apps heat up cheap phones. Everything here — including chroma smear and
halation — is folded into ~20 texture taps in a single pass at the tape's
quantised resolution.

**The viewfinder never rebuilds.** The animation clock is published through a
`ValueNotifier` consumed by a `ListenableBuilder` that keeps the camera preview
as a preserved `child`. The preview subtree is repainted every frame but never
rebuilt, which is the difference between a smooth and a stuttering viewfinder.

**Video is captured, not re-filtered.** The recorder reads the composited
viewfinder back off its `RepaintBoundary` and pushes raw RGBA straight into the
platform encoder. The loop is driven by a wall clock: if a GPU readback runs
long, the previous frame is repeated, so the picture can never drift away from
the microphone. Audio is drained in exact `sampleRate / fps` chunks and padded
with silence on underrun, which keeps A/V sync deterministic. The default
360p / 30fps encode is deliberately small — a real VHS master was ~333x480.

---

## Tuning tips

- **Tape resolution** (status strip) sets the encode size, not the look. Drop it
  to `VHS 240p` on older phones for a rock-solid 30fps recording.
- **Tape lines** (effects panel) sets how much detail the emulated tape can
  resolve. Low values are more destroyed and also slightly cheaper to render.
- Turn **burn in date stamp** off if you want a clean frame; the `REC` counter is
  always burnt in while recording, exactly like a real camcorder.
- Framing defaults to **4:3** because that is VHS's native aspect ratio.

## Known limitations

- Recording resolution is capped by the viewfinder's on-screen size, since frames
  are read back from what is composited. This is intentional — it guarantees
  WYSIWYG output.
- Photos are saved as PNG (lossless, but larger than JPEG).
- Landscape orientation is not supported; a camcorder is a portrait device here.
