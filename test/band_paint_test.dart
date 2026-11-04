import 'package:druna_app/features/calendar/band_paint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the band fades 100% → 55% → 20% → 0 at 0, 35%, 70% and 100%', () {
    expect(bandFade(0), closeTo(1, 1e-9));
    expect(bandFade(0.35), closeTo(0.55, 1e-9));
    expect(bandFade(0.7), closeTo(0.2, 1e-9));
    expect(bandFade(1), closeTo(0, 1e-9));
  });

  test('the band only ever fades', () {
    var last = bandFade(0);
    for (var i = 1; i <= 300; i++) {
      final next = bandFade(i / 300);
      expect(next, lessThanOrEqualTo(last + 1e-12), reason: '${i / 300}');
      last = next;
    }
  });
}
