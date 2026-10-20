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
    test('has sixteen distinct colours', () {
      expect(avatarPalette, hasLength(16));
      expect(avatarPalette.toSet(), hasLength(16));
    });

    test('is the same for the same person', () {
      expect(avatarColorFor(id: 7), avatarColorFor(id: 7));
      expect(avatarColorFor(id: 23), avatarColorFor(id: 7));
      expect({
        for (var id = 1; id <= 16; id++) avatarColorFor(id: id),
      }, hasLength(16));
      expect(
        avatarColorFor(id: 0, username: 'Alina'),
        avatarColorFor(id: 0, username: 'alina'),
      );
    });

    test('neighbouring ids get hues far apart', () {
      final a = avatarSlotFor(101);
      final b = avatarSlotFor(102);
      final distance = (a - b).abs();
      expect(distance < 16 - distance ? distance : 16 - distance, 7);
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

  testWidgets('draws the initial on the palette colour', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: PersonAvatar(id: 3, name: 'Марк'),
      ),
    );

    expect(find.text('М'), findsOneWidget);
    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, avatarColorFor(id: 3));
  });
}
