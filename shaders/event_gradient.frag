#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uPhase;
uniform vec4 uC0;
uniform vec4 uC1;
uniform vec4 uC2;
uniform vec4 uC3;
uniform vec4 uC4;
uniform vec4 uC5;
uniform vec3 uDark;

out vec4 fragColor;

vec3 toSrgb(vec3 c) {
  c = clamp(c, 0.0, 1.0);
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055,
             step(0.0031308, c));
}

vec3 fromOklab(vec3 lab) {
  vec3 lms = vec3(
    lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z,
    lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z,
    lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z);
  lms = lms * lms * lms;
  return toSrgb(vec3(
    4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
    -1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
    -0.0041960863 * lms.x - 0.7034186167 * lms.y + 1.7076147010 * lms.z));
}

vec4 stop(int i) {
  if (i == 0) return uC0;
  if (i == 1) return uC1;
  if (i == 2) return uC2;
  if (i == 3) return uC3;
  if (i == 4) return uC4;
  return uC5;
}

float radius(vec2 p, vec2 major) {
  vec2 minor = vec2(-major.y, major.x);
  return length(vec2(dot(p, major), 2.2 * dot(p, minor)));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - 0.5 * uSize) / uSize.y;
  vec2 half_ = vec2(0.5 * uSize.x / uSize.y, 0.5);
  vec2 major = normalize(half_);
  float far = max(radius(half_, major), radius(vec2(half_.x, -half_.y), major));
  float r = radius(p, major) / far;

  float total = 0.0;
  for (int i = 0; i < 6; i++) {
    total += stop(i).w;
  }
  vec3 lab = vec3(0.0);
  if (total > 0.001) {
    float span = max(total - 1.0, 0.5) / total;
    float s = fract(r * span - uPhase * 0.25) * total;
    float start = 0.0;
    int at = -1;
    float f = 0.0;
    for (int i = 0; i < 6; i++) {
      float w = stop(i).w;
      if (w <= 0.001) continue;
      if (at < 0 && s < start + w) {
        at = i;
        f = (s - start) / w;
      }
      start += w;
    }
    if (at < 0) at = 0;
    int next = at;
    for (int k = 1; k <= 6; k++) {
      int j = int(mod(float(at + k), 6.0));
      if (stop(j).w > 0.001) {
        next = j;
        break;
      }
    }
    lab = mix(stop(at).xyz, stop(next).xyz, smoothstep(0.0, 1.0, f));
  }
  float y = frag.y / uSize.y;
  lab = mix(lab, uDark, 0.8 * smoothstep(0.38, 1.0, y));

  fragColor = vec4(fromOklab(lab), 1.0);
}
