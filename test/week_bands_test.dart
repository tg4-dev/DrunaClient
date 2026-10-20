import 'package:druna_app/features/calendar/week_bands.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 50.0;
const _pink = Color(0xFFE040C8);
const _green = Color(0xFF34C759);
const _yellow = Color(0xFFFFB800);

/// A chip over days [first]..[last] of the week, with the usual insets.
BandChip _chip(int first, int last, Color color) =>
    BandChip(left: first * _w + 2, right: (last + 1) * _w - 2, color: color);

void main() {
  test('days in a row make one band; an empty day splits it', () {
    // As in the reference: busy Mon–Tue, free Wed, busy Thu–Sun.
    final bands = buildWeekBands([
      _chip(0, 0, _pink),
      _chip(1, 1, _green),
      _chip(3, 4, _pink),
      _chip(4, 5, _yellow),
      _chip(6, 6, _green),
    ], columnWidth: _w);

    expect(bands, hasLength(2));
    expect(bands[0].left, 2);
    expect(bands[0].right, 2 * _w - 2);
    expect(bands[1].left, 3 * _w + 2);
    expect(bands[1].right, 7 * _w - 2);
  });

  test('colours sit at event centres and blend in between', () {
    final band = buildWeekBands([
      _chip(0, 0, _pink),
      _chip(1, 1, _green),
    ], columnWidth: _w).single;

    expect(band.colors.first, _pink);
    expect(band.colors.last, _green);
    expect(band.stops.first, 0);
    expect(band.stops.last, 1);
    expect(band.colors.length, band.stops.length);
    for (var i = 1; i < band.stops.length; i++) {
      expect(band.stops[i], greaterThanOrEqualTo(band.stops[i - 1]));
    }
    // Pink centre at a quarter of the band, green at three quarters.
    expect(band.stops[1], closeTo(0.25, 0.02));
    expect(band.stops[band.stops.length - 2], closeTo(0.75, 0.02));
  });

  test('points closer than half a day merge; the longer event wins', () {
    final band = buildWeekBands([
      _chip(2, 2, _green),
      _chip(1, 3, _pink),
    ], columnWidth: _w).single;

    expect(band.colors.toSet(), {_pink});
  });

  test('one colour is a solid band', () {
    final band = buildWeekBands([_chip(2, 4, _yellow)], columnWidth: _w).single;
    expect(band.colors, [_yellow, _yellow]);
    expect(band.stops, [0, 1]);
  });

  test('my events: one solid colour per run', () {
    final bands = buildSolidBands([
      _chip(0, 0, _pink),
      _chip(1, 1, _green),
      _chip(5, 5, _yellow),
    ], _green);

    expect(bands, hasLength(2));
    for (final band in bands) {
      expect(band.colors, [_green, _green]);
    }
  });

  test('no events, no bands', () {
    expect(buildWeekBands(const [], columnWidth: _w), isEmpty);
  });
}
