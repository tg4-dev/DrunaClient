import 'package:druna_app/shared/ui/color_mix.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _saturation(Color color) => HSVColor.fromColor(color).saturation;

void main() {
  const pink = Color(0xFFE040C8);
  const green = Color(0xFF34C759);

  test('the ends are the colours themselves', () {
    expect(mixOklch(pink, green, 0), pink);
    expect(mixOklch(pink, green, 1), green);
    final almost = mixOklch(pink, pink, 0.5);
    expect(almost.r, closeTo(pink.r, 0.01));
    expect(almost.g, closeTo(pink.g, 0.01));
    expect(almost.b, closeTo(pink.b, 0.01));
  });

  test('blue to yellow does not pass through white or grey', () {
    const blue = Color(0xFF0A84FF);
    const yellow = Color(0xFFFFB800);
    final middle = mixOklch(blue, yellow, 0.5);
    expect(_saturation(middle), greaterThan(0.5));
  });

  test('pink to green stays colourful in the middle', () {
    final oklab = mixOklch(pink, green, 0.5);
    final rgb = Color.lerp(pink, green, 0.5)!;
    expect(_saturation(oklab), greaterThan(_saturation(rgb)));
  });
}
