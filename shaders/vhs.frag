#version 460 core

// ---------------------------------------------------------------------------
// VHS tape emulation - single pass, mobile friendly.
//
// Signal chain (mirrors what a real VHS deck does to a picture):
//   1. CRT barrel geometry + tape transport wobble / head-switching tear
//   2. Composite luma/chroma separation in YIQ space
//   3. Chroma sub-sampling smear (the "color bleed")
//   4. RF chromatic misalignment + delay-line ghosting
//   5. Luma edge ringing (the sharpening halo of consumer camcorders)
//   6. Line quantisation, scanlines, interlace flicker
//   7. Tape noise, dropouts, bloom, vignette and colour grade
//
// Uniform order is authoritative: it maps 1:1 onto VhsSettings.toUniforms().
// ---------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;              // 0, 1  - draw size in logical pixels
uniform float uTime;             // 2     - seconds, wrapped to keep precision
uniform float uChromaticShift;   // 3     - RF colour misalignment
uniform float uColorBleed;       // 4     - chroma sub-sampling smear
uniform float uScanlines;        // 5     - scanline + interlace strength
uniform float uNoise;            // 6     - tape grain + dropouts
uniform float uTracking;         // 7     - tracking band / head-switch tear
uniform float uWarp;             // 8     - horizontal transport jitter
uniform float uSaturation;       // 9     - chroma gain
uniform float uContrast;         // 10
uniform float uBrightness;       // 11
uniform float uVignette;         // 12
uniform float uBloom;            // 13    - highlight halation
uniform float uTapeLines;        // 14    - vertical resolution of the tape
uniform float uCurvature;        // 15    - CRT barrel / fisheye
uniform float uSharpen;          // 16    - luma edge ringing
uniform float uGhosting;         // 17    - delay-line echo
uniform float uTint;             // 18    - -1 green .. +1 magenta

uniform sampler2D uTexture;

out vec4 fragColor;

const float kTau = 6.28318530718;
const int kBleedTaps = 6;

// Y'IQ is the composite colour space NTSC (and therefore VHS) actually uses.
const mat3 kRgbToYiq = mat3(
    0.299, 0.5959, 0.2115,
    0.587, -0.2746, -0.5227,
    0.114, -0.3213, 0.3112);

const mat3 kYiqToRgb = mat3(
    1.0, 1.0, 1.0,
    0.956, -0.272, -1.106,
    0.619, -0.647, 1.703);

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Smooth 1D value noise, used for the slow tape transport wobble.
float wobble(float x) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(vec2(i, 7.0));
    float b = hash21(vec2(i + 1.0, 7.0));
    return mix(a, b, f) * 2.0 - 1.0;
}

vec3 tap(vec2 uv) {
    return texture(uTexture, clamp(uv, vec2(0.0015), vec2(0.9985))).rgb;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    float aspect = uSize.x / max(uSize.y, 1.0);
    float t = uTime;

    // --- 1. CRT barrel geometry ---------------------------------------------
    vec2 centered = uv * 2.0 - 1.0;
    float r2 = dot(centered, centered);
    centered *= 1.0 + uCurvature * r2 * 0.28;
    uv = centered * 0.5 + 0.5;

    // Everything outside the glass is tape black, not stretched pixels.
    vec2 edge = smoothstep(vec2(0.0), vec2(0.006), uv) *
                (1.0 - smoothstep(vec2(0.994), vec2(1.0), uv));
    float bezel = edge.x * edge.y;

    // --- 2. Tape transport instability --------------------------------------
    float lines = max(uTapeLines, 32.0);
    float row = floor(uv.y * lines);
    float rowJitter = hash21(vec2(row, floor(t * 22.0))) - 0.5;
    float slowWobble = wobble(uv.y * 3.0 + t * 0.7) * 0.55 +
                       wobble(uv.y * 17.0 - t * 2.1) * 0.45;
    uv.x += (rowJitter * 0.30 + slowWobble * 0.70) * uWarp * 0.012;

    // Tracking band: a slowly drifting horizontal region of torn signal.
    float bandY = fract(-t * 0.14);
    float bandDist = abs(uv.y - bandY);
    bandDist = min(bandDist, 1.0 - bandDist);
    float band = smoothstep(0.05, 0.0, bandDist) * uTracking;
    uv.x += band * (hash21(vec2(row * 1.7, floor(t * 45.0))) - 0.5) * 0.09;

    // Head-switching noise: the torn strip at the bottom of every VHS frame.
    float headSwitch = smoothstep(0.972, 1.0, uv.y) * uTracking;
    uv.x += headSwitch * (hash21(vec2(row, floor(t * 30.0))) - 0.5) * 0.22;

    // --- 3. Line quantisation (the tape simply cannot resolve more) ---------
    vec2 tapeRes = vec2(max(lines * 1.25 * aspect, 48.0), lines);
    uv = (floor(uv * tapeRes) + 0.5) / tapeRes;

    float px = 1.0 / tapeRes.x;

    // --- 4. Chroma sub-sampling smear + RF misalignment ---------------------
    float bleed = px * (0.6 + uColorBleed * 9.0);
    float shift = px * uChromaticShift * 5.0;

    vec3 centerRgb = vec3(
        tap(uv + vec2(shift, 0.0)).r,
        tap(uv).g,
        tap(uv - vec2(shift, 0.0)).b);

    vec3 chroma = vec3(0.0);
    float weight = 0.0;
    for (int i = 0; i < kBleedTaps; i++) {
        float fi = float(i);
        float w = 1.0 - fi / float(kBleedTaps);
        chroma += kRgbToYiq * tap(uv - vec2(fi * bleed, 0.0)) * w;
        weight += w;
    }
    chroma /= weight;

    // --- 5. Luma with camcorder edge ringing -------------------------------
    float luma = (kRgbToYiq * centerRgb).x;
    float lumaL = (kRgbToYiq * tap(uv - vec2(px * 2.0, 0.0))).x;
    float lumaR = (kRgbToYiq * tap(uv + vec2(px * 2.0, 0.0))).x;
    luma += (luma * 2.0 - lumaL - lumaR) * uSharpen * 0.9;

    vec3 color =
        kYiqToRgb * vec3(luma, chroma.y * uSaturation, chroma.z * uSaturation);

    // --- 6. Delay-line ghost ------------------------------------------------
    vec3 ghost = tap(uv - vec2(px * 9.0, 0.0));
    color += ghost * uGhosting * 0.22;

    // --- 7. Halation around highlights -------------------------------------
    if (uBloom > 0.001) {
        float by = 1.0 / tapeRes.y;
        vec3 soft = (tap(uv + vec2(px * 3.0, 0.0)) +
                     tap(uv - vec2(px * 3.0, 0.0)) +
                     tap(uv + vec2(0.0, by * 2.0)) +
                     tap(uv - vec2(0.0, by * 2.0))) * 0.25;
        color += max(soft - 0.62, vec3(0.0)) * uBloom * 2.2;
    }

    // --- 8. Scanlines + interlace flicker ----------------------------------
    float scan = 0.5 + 0.5 * cos(uv.y * lines * kTau);
    color *= mix(1.0, 0.55 + 0.45 * scan, uScanlines);
    float field = mod(row + floor(t * 50.0), 2.0);
    color *= 1.0 - uScanlines * 0.05 * field;

    // Tracking band also lifts and desaturates the signal.
    color = mix(color, vec3(dot(color, vec3(0.33))) + 0.16, band * 0.55);
    color = mix(color, vec3(hash21(uv * 900.0 + t)), headSwitch * 0.85);

    // --- 9. Tape grain + dropouts ------------------------------------------
    float grain = hash21(uv * uSize + vec2(t * 91.7, t * 47.3));
    color += (grain - 0.5) * uNoise * 0.30;

    float dropSeed = hash21(vec2(row * 3.7, floor(t * 9.0)));
    float dropout = step(1.0 - uNoise * 0.10, dropSeed);
    float dropX = hash21(vec2(row * 11.3, floor(t * 9.0) + 31.0));
    float dropSpan = smoothstep(0.045, 0.0, abs(uv.x - dropX));
    color += dropout * dropSpan * 0.85;

    // --- 10. Grade: lifted blacks, tape tint, contrast ----------------------
    color = (color - 0.5) * uContrast + 0.5 + uBrightness;
    color = color * 0.93 + 0.05;
    float magenta = max(uTint, 0.0);
    float green = max(-uTint, 0.0);
    color.r += magenta * 0.045;
    color.b += magenta * 0.055;
    color.g += green * 0.05;

    // --- 11. Vignette + bezel ----------------------------------------------
    vec2 vc = uv - 0.5;
    color *= clamp(1.0 - dot(vc, vc) * uVignette * 1.7, 0.0, 1.0);
    color *= bezel;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
