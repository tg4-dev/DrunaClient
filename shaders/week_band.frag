#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uFromTop;
uniform float uFade;
uniform float uOpacity;
uniform float uCount;
uniform vec4 uC0;
uniform vec4 uC1;
uniform vec4 uC2;
uniform vec4 uC3;
uniform vec4 uC4;
uniform vec4 uC5;
uniform vec4 uC6;
uniform vec4 uC7;
uniform vec2 uMid;
uniform vec3 uRadial;
uniform vec2 uRadialStops;

out vec4 fragColor;

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

float hermite(float t, float h, float y0, float m0, float y1, float m1) {
  float t2 = t * t;
  float t3 = t2 * t;
  return (2.0 * t3 - 3.0 * t2 + 1.0) * y0 + (t3 - 2.0 * t2 + t) * h * m0 +
         (-2.0 * t3 + 3.0 * t2) * y1 + (t3 - t2) * h * m1;
}

float fade(float d) {
  float x = clamp(d, 0.0, 1.0);
  if (x < 0.35) {
    return hermite(x / 0.35, 0.35, 1.0, -9.0 / 7.0, 0.55, -8.0 / 7.0);
  }
  if (x < 0.7) {
    return hermite((x - 0.35) / 0.35, 0.35, 0.55, -8.0 / 7.0, 0.2, -5.0 / 6.0);
  }
  return hermite((x - 0.7) / 0.3, 0.3, 0.2, -5.0 / 6.0, 0.0, 0.0);
}

float noise(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

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
