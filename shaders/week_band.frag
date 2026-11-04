#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// A busy band on a week line (lib/features/calendar/band_paint.dart):
// the colours of the events run along it, and it fades from the line
// towards the middle of the week. One pass, exact alpha — the old thin
// slices of falling opacity showed as steps — and a touch of noise
// against 8-bit banding on black.

// The band's rect in the canvas.
uniform vec2 uOrigin;
uniform vec2 uSize;
// 1: the line is the top edge; 0: the bottom edge.
uniform float uFromTop;
// The fade reaches nothing this far from the line.
uniform float uFade;
uniform float uOpacity;
// How many stops are in use, 1..8.
uniform float uCount;
// Straight sRGB colour, the stop's position along the band in w (0..1).
uniform vec4 uC0;
uniform vec4 uC1;
uniform vec4 uC2;
uniform vec4 uC3;
uniform vec4 uC4;
uniform vec4 uC5;
uniform vec4 uC6;
uniform vec4 uC7;
// Optional middle anchor: at x px from the line the alpha is y; past it,
// it eases to 0 at uFade. x <= 0 keeps the band's own curve.
uniform vec2 uMid;
// Optional radial mask multiplied in: centre (x, y) in the rect, radius z;
// clear up to uRadialStops.x of the radius, full from uRadialStops.y. z <= 0
// turns it off.
uniform vec3 uRadial;
uniform vec2 uRadialStops;

out vec4 fragColor;

// The stops by index (SkSL has no array initializers).
vec4 stop(int i) {
  if (i == 0) return uC0;
  if (i == 1) return uC1;
  if (i == 2) return uC2;
  if (i == 3) return uC3;
  if (i == 4) return uC4;
  if (i == 5) return uC5;
  if (i == 6) return uC6;
  return uC7;
}

// Plain RGB between neighbours, like the gradient it replaces.
vec3 along(float x) {
  vec4 previous = uC0;
  if (x <= previous.w) return previous.rgb;
  for (int i = 1; i < 8; i++) {
    if (float(i) >= uCount) break;
    vec4 next = stop(i);
    if (x <= next.w) {
      float span = max(next.w - previous.w, 1e-4);
      return mix(previous.rgb, next.rgb, (x - previous.w) / span);
    }
    previous = next;
  }
  return previous.rgb;
}

// 100% at the line, about 55% at a third, 20% at two thirds, 0 at the end.
float fade(float d) {
  float k = 1.0 - clamp(d, 0.0, 1.0);
  return k * k * (0.45 + 0.55 * k);
}

float noise(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 1 at the line, uMid.y at uMid.x, easing to 0 at uFade.
float anchored(float d) {
  if (d <= uMid.x) return mix(1.0, uMid.y, d / uMid.x);
  float f = clamp((d - uMid.x) / max(uFade - uMid.x, 1.0), 0.0, 1.0);
  return uMid.y * (1.0 - smoothstep(0.0, 1.0, f));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = frag - uOrigin;
  float x = clamp(p.x / max(uSize.x, 1.0), 0.0, 1.0);
  float fromLine = uFromTop > 0.5 ? p.y : uSize.y - p.y;
  float alpha = (uMid.x > 0.0 ? anchored(fromLine)
                              : fade(fromLine / max(uFade, 1.0))) * uOpacity;
  if (uRadial.z > 0.0) {
    float r = length(p - uRadial.xy) / uRadial.z;
    alpha *= smoothstep(uRadialStops.x, uRadialStops.y, r);
  }
  alpha = clamp(alpha + (noise(frag) - 0.5) / 255.0, 0.0, 1.0);
  fragColor = vec4(along(x) * alpha, alpha);
}
