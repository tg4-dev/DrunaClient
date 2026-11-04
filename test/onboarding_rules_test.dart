import 'package:druna_app/features/onboarding/onboarding_rules.dart';
import 'package:druna_app/features/onboarding/onboarding_steps.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('accepts ordinary addresses and lowers the domain only', () {
      expect(emailError('alice@example.com'), isNull);
      expect(emailError(' a.b+tag@Mail.Example.RU '), isNull);
      expect(normalizeEmail(' Alice@GMail.COM '), 'Alice@gmail.com');
    });

    test('refuses broken ones', () {
      for (final bad in [
        '',
        'alice',
        'alice@',
        '@example.com',
        'alice@example',
        'al ice@example.com',
        'alice..b@example.com',
        '.alice@example.com',
        'alice@example.c',
      ]) {
        expect(emailError(bad), isNotNull, reason: bad);
      }
    });

    test('lights the arrow once it looks like an email', () {
      expect(looksLikeEmail('alice@'), isFalse);
      expect(looksLikeEmail('alice@mail'), isFalse);
      expect(looksLikeEmail('alice@mail.'), isFalse);
      expect(looksLikeEmail('alice@mail.r'), isTrue);
    });

    test('suggests a well-known domain for a typo', () {
      expect(emailSuggestion('alice@gmial.com'), 'alice@gmail.com');
      expect(emailSuggestion('alice@gmail.co'), 'alice@gmail.com');
      expect(emailSuggestion('alice@yandex.ri'), 'alice@yandex.ru');
      expect(emailSuggestion('alice@gmail.com'), isNull);
      expect(emailSuggestion('alice@company.org'), isNull);
    });
  });

  test('password: the server minimum and a matching repeat', () {
    expect(passwordError('short', 'short'), 'минимум 8 символов');
    expect(passwordError('long enough', 'long enougH'), 'пароли не совпадают');
    expect(passwordError('long enough', 'long enough'), isNull);
  });

  test('username: 3–32 of latin letters, digits, _ and .', () {
    expect(usernameError('@al'), 'минимум 3 символа');
    expect(usernameError('@alice_01.x'), isNull);
    expect(usernameError('@алиса'), 'только латиница, цифры, _ и .');
    expect(usernameError('@${'a' * 33}'), 'максимум 32 символа');
    expect(normalizeUsername(' @Alice '), 'alice');
  });

  test('the username field: lower case, no spaces, no typed "@"', () {
    const formatter = UsernameFormatter();
    TextEditingValue type(String text) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );
    expect(type('Ali Ce').text, 'alice');
    expect(type('@@bob').text, 'bob');
    expect(type('').text, '');
  });

  test('name: at least three letters after trimming', () {
    expect(nameError('  Ая  '), 'минимум 3 символа');
    expect(nameError('Аня'), isNull);
  });

  test('name: no emoji, letters counted as people see them', () {
    for (final name in ['Глеб 😀', '👩🏽‍💻 Аня', 'Аня 🇷🇺', 'Аня ❤️']) {
      expect(nameError(name), 'без эмодзи', reason: name);
    }
    expect(nameError('Анна-Мария'), isNull);
    expect(nameError('Zoë'), isNull);
    expect(nameError('й' * 32), isNull);
  });

  test('names are shown in capitals, the value stays as typed', () {
    expect(shownName(' Глеб '), 'ГЛЕБ');
    expect(upperSameLength('straße'), 'STRAßE');
    final controller = UpperCaseNameController(text: 'Аня');
    expect(controller.text, 'Аня');
    controller.dispose();
  });
}
