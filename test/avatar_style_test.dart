import 'dart:math' as math;

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/oklab.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/profile_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avatarShade', () {
    test('is darker and keeps the hue', () {
      for (final color in avatarPalette) {
        final (l, a, b) = oklab(color);
        final (sl, sa, sb) = oklab(avatarShade(color));
        // Saturated colours leave sRGB when darkened and are clipped back:
        // the lightness drops all the same, the hue barely moves.
        expect(sl, lessThan(l * 0.8));
        final hue = math.atan2(b, a);
        final shadeHue = math.atan2(sb, sa);
        expect((hue - shadeHue).abs(), lessThan(0.05), reason: '$color');
      }
    });

    test('OKLab goes there and back', () {
      for (final color in avatarPalette) {
        final back = fromOklab(oklab(color));
        expect((back.r - color.r).abs(), lessThan(0.005));
        expect((back.g - color.g).abs(), lessThan(0.005));
        expect((back.b - color.b).abs(), lessThan(0.005));
      }
    });
  });

  group('AvatarFont', () {
    test('six fonts with distinct ids; an unknown id falls back', () {
      expect(avatarFonts, hasLength(6));
      expect(avatarFonts.map((f) => f.id).toSet(), hasLength(6));
      expect(avatarFontById('nope'), defaultAvatarFont);
      expect(avatarFontById(null), defaultAvatarFont);
    });

    test('the case comes with the font', () {
      expect(avatarFontById('onest').cased('г'), 'Г');
      expect(avatarFontById('playfair').cased('Г'), 'г');
    });

    test('the ink box follows capitals, ascenders and descenders', () {
      final font = defaultAvatarFont;
      expect(inkBox(font, 'А'), (font.capHeight, 0.0));
      expect(inkBox(font, 'а'), (font.xHeight, 0.0));
      expect(inkBox(font, 'б'), (font.ascender, 0.0));
      expect(inkBox(font, 'у'), (font.xHeight, -font.descender));
      expect(inkBox(font, 'Щ'), (font.capHeight, -font.descender));
    });

    test('the tuning screen prints code that keeps every value', () {
      final tuned = avatarFontById('lobster').copyWith(dx: 0.01, dy: -0.02);
      final code = tuned.toCode();
      expect(code, contains("id: 'lobster'"));
      expect(code, contains('dx: 0.010'));
      expect(code, contains('dy: -0.020'));
      expect(code, contains('uppercase: false'));
    });
  });

  group('AppSettings', () {
    test(
      'a slot of the old palette of 16 is dropped; the font is kept',
      () async {
        final storage = MemorySettingsStorage()
          ..values['settings.own_color'] = '12'
          ..values['settings.own_font'] = 'oswald';
        final settings = AppSettings(storage: storage, demoByDefault: false);
        await settings.load();
        expect(settings.ownColorSlot, isNull);
        expect(ownFontFor(settings).id, 'oswald');

        settings
          ..ownColorSlot = 5
          ..ownFontId = 'comfortaa';
        final again = AppSettings(storage: storage, demoByDefault: false);
        await again.load();
        expect(again.ownColorSlot, 5);
        expect(again.ownFontId, 'comfortaa');
        settings.dispose();
        again.dispose();
      },
    );
  });

  testWidgets('the pickers pick with a tap and a tick', (tester) async {
    final ticks = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          ticks.add(call.arguments as String);
        }
        return null;
      },
    );
    var font = defaultAvatarFont;
    var slot = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              FontPicker(
                name: 'Аня',
                selected: font,
                onPick: (f) => setState(() => font = f),
              ),
              ColorPicker(
                selected: slot,
                onPick: (s) => setState(() => slot = s),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('font-oswald')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-3')));
    await tester.pumpAndSettle();
    expect(font.id, 'oswald');
    expect(slot, 3);
    expect(ticks, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);

    // The picked one again: nothing happens, no tick.
    await tester.tap(find.byKey(const ValueKey('color-3')));
    await tester.pumpAndSettle();
    expect(ticks, hasLength(2));
  });
}
