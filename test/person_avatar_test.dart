import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avatarInitial', () {
    test('takes the first letter of the name, upper-cased', () {
      expect(avatarInitial('алина смирнова'), 'А');
      expect(avatarInitial('  mark'), 'M');
    });

    test('falls back to the username, then to a question mark', () {
      expect(avatarInitial('', 'nika'), 'N');
      expect(avatarInitial('  ', '@eva'), 'E');
      expect(avatarInitial('', ''), '?');
    });

    test('keeps a whole grapheme', () {
      expect(avatarInitial('👩🏽‍💻 Dev'), '👩🏽‍💻');
    });
  });

  group('avatarColorFor', () {
    test('has eight distinct colours', () {
      expect(avatarPalette, hasLength(8));
      expect(avatarPalette.toSet(), hasLength(8));
    });

    test('is the same for the same person', () {
      expect(avatarColorFor(id: 7), avatarColorFor(id: 7));
      expect(avatarColorFor(id: 15), avatarColorFor(id: 7));
      expect({
        for (var id = 1; id <= 8; id++) avatarColorFor(id: id),
      }, hasLength(8));
      expect(
        avatarColorFor(id: 0, username: 'Alina'),
        avatarColorFor(id: 0, username: 'alina'),
      );
    });

    test('neighbouring ids get hues far apart', () {
      final a = avatarSlotFor(101);
      final b = avatarSlotFor(102);
      final distance = (a - b).abs();
      expect(distance < 8 - distance ? distance : 8 - distance, 3);
    });

    test('spreads usernames over the palette', () {
      final colours = {
        for (final name in ['alina', 'mark', 'nika', 'max', 'eva', 'nikita'])
          avatarColorFor(id: 0, username: name),
      };
      expect(colours.length, greaterThan(3));
    });
  });

  test('ink is black on light colours and white on dark ones', () {
    expect(avatarInkFor(const Color(0xFFFFD60A)), Colors.black);
    expect(avatarInkFor(const Color(0xFF4C5BFF)), Colors.white);
  });

  testWidgets('draws the initial on a 45° gradient of the palette colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: PersonAvatar(id: 3, name: 'Марк'),
      ),
    );

    final letter = tester.widget<AvatarLetter>(find.byType(AvatarLetter));
    expect(letter.letter, 'М');
    expect(letter.font, defaultAvatarFont);
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final gradient =
        (box.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.colors.first, avatarColorFor(id: 3));
    expect(gradient.colors.last, avatarShade(avatarColorFor(id: 3)));
  });

  testWidgets('the user\'s own avatar takes their colour and font', (
    tester,
  ) async {
    final lobster = avatarFontById('lobster');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: OwnAvatar(
          id: 3,
          color: avatarPalette[5],
          font: lobster,
          child: const PersonAvatar(id: 3, name: 'Марк'),
        ),
      ),
    );
    final letter = tester.widget<AvatarLetter>(find.byType(AvatarLetter));
    expect(letter.font, lobster);
    expect(letter.letter, 'м');
  });
}
