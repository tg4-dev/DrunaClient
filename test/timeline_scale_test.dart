import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hour zoom snaps to the nearest grid level', () {
    expect(nearestTimelinePixels(46), 46);
    expect(nearestTimelinePixels(40), 46);
    expect(nearestTimelinePixels(20), 18);
    expect(nearestTimelinePixels(92), 92);
    expect(nearestTimelinePixels(30), 28);
    expect(nearestTimelinePixels(13), 12);
  });

  test('each level shows its own division of hours', () {
    // 6 h: midnight, 6, 12, 18.
    expect(hourLineOpacity(6, 12), 1);
    expect(hourLineOpacity(18, 12), 1);
    expect(hourLineOpacity(4, 12), 0);
    // 4 h: 6 and 18 fade out, 4 and 8 come in.
    expect(hourLineOpacity(4, 18), 1);
    expect(hourLineOpacity(6, 18), 0);
    expect(hourLineOpacity(6, 15), closeTo(0.5, 0.01));
    expect(hourLineOpacity(0, 15), 1);
    // 2 h, then every hour.
    expect(hourLineOpacity(6, 28), 1);
    expect(hourLineOpacity(2, 18), 0);
    expect(hourLineOpacity(1, 28), 0);
    expect(hourLineOpacity(1, 46), 1);
    expect(halfHourOpacity(46), 0);
    expect(halfHourOpacity(92), 1);
  });

  test('the drawing step follows the division', () {
    expect(timelineStepFor(12), 120);
    expect(timelineStepFor(18), 60);
    expect(timelineStepFor(28), 60);
    expect(timelineStepFor(46), 30);
    expect(timelineStepFor(92), 30);
    expect(timelineDivisionFor(46), 60);
  });

  group('snapWithMagnet', () {
    int snap(double raw, {int? current, int step = 30, int division = 60}) =>
        snapWithMagnet(
          raw: raw,
          current: current,
          step: step,
          division: division,
        );

    test('rounds to the step', () {
      expect(snap(9 * 60 + 40), 9 * 60 + 30);
      expect(snap(9 * 60 + 14, division: 30), 9 * 60);
    });

    test('pulls to a whole hour within 30% of a step', () {
      // 09:51 would round to 10:00 anyway; 09:52 too. 09:44 rounds to
      // 09:30, but 09:52 is within 9 minutes of 10:00.
      expect(snap(9 * 60 + 52), 10 * 60);
      // 10:08 rounds to 10:00 and stays there.
      expect(snap(10 * 60 + 8), 10 * 60);
      // Just outside the pull, the half hour wins.
      expect(snap(10 * 60 + 20), 10 * 60 + 30);
    });

    test('holds the current value near a boundary', () {
      // 09:47 would round to 10:00, but 10:00 holds until 09:42.
      expect(snap(9 * 60 + 47, current: 10 * 60), 10 * 60);
      expect(snap(9 * 60 + 41, current: 10 * 60), 9 * 60 + 30);
    });

    test('a coarse step still finds the labelled lines', () {
      expect(snap(5 * 60 + 20, step: 120, division: 360), 6 * 60);
      expect(snap(3 * 60 + 10, step: 120, division: 360), 4 * 60);
    });
  });
}
