import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hour zoom snaps to the nearest grid level', () {
    expect(nearestTimelinePixels(46), 46);
    expect(nearestTimelinePixels(40), 46);
    expect(nearestTimelinePixels(20), 18);
    expect(nearestTimelinePixels(92), 92);
    expect(nearestTimelinePixels(30), 28);
  });

  test('hour lines fade in as the scale grows', () {
    expect(hourLineOpacity(0, 18), 1);
    expect(hourLineOpacity(2, 18), 0);
    expect(hourLineOpacity(1, 28), 0);
    expect(hourLineOpacity(1, 46), 1);
    expect(halfHourOpacity(46), 0);
    expect(halfHourOpacity(92), 1);
  });
}
