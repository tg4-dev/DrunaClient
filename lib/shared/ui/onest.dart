import 'package:flutter/material.dart';

/// Onest at [weight]: the font is variable, and its `wght` axis follows
/// only an explicit variation, not [FontWeight] alone.
TextStyle onest(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = Colors.white,
  double? height,
  double? letterSpacing,
  List<FontFeature>? features,
}) => TextStyle(
  fontFamily: 'Onest',
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  color: color,
  height: height,
  letterSpacing: letterSpacing,
  fontFeatures: features,
);
