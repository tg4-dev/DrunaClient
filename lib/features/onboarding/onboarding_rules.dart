library;

import 'package:flutter/widgets.dart' show StringCharacters;

String normalizeEmail(String raw) {
  final email = raw.trim();
  final at = email.lastIndexOf('@');
  if (at < 0) return email;
  return email.substring(0, at + 1) + email.substring(at + 1).toLowerCase();
}

final _email = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
);

bool looksLikeEmail(String raw) {
  final email = raw.trim();
  final at = email.indexOf('@');
  return at > 0 && email.indexOf('.', at) > at + 1 && !email.endsWith('.');
}

String? emailError(String raw) {
  final email = normalizeEmail(raw);
  if (email.isEmpty) return 'введи почту';
  final local = email.split('@').first;
  final valid =
      _email.hasMatch(email) &&
      email.length <= 254 &&
      local.length <= 64 &&
      !local.startsWith('.') &&
      !local.endsWith('.') &&
      !email.contains('..');
  return valid ? null : 'неверный формат';
}

const _domains = [
  'gmail.com',
  'mail.ru',
  'yandex.ru',
  'ya.ru',
  'icloud.com',
  'me.com',
  'outlook.com',
  'hotmail.com',
  'yahoo.com',
  'bk.ru',
  'inbox.ru',
  'list.ru',
  'rambler.ru',
  'proton.me',
];

String? emailSuggestion(String raw) {
  final email = normalizeEmail(raw);
  final at = email.lastIndexOf('@');
  if (at <= 0) return null;
  final domain = email.substring(at + 1);
  if (domain.isEmpty || _domains.contains(domain)) return null;
  String? best;
  var bestDistance = 3;
  for (final known in _domains) {
    final distance = _distance(domain, known);
    if (distance < bestDistance) {
      best = known;
      bestDistance = distance;
    }
  }
  if (best == null || bestDistance > (best.length > 8 ? 2 : 1)) return null;
  return '${email.substring(0, at)}@$best';
}

int _distance(String a, String b) {
  final d = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = [
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        best = best < d[i - 2][j - 2] + 1 ? best : d[i - 2][j - 2] + 1;
      }
      d[i][j] = best;
    }
  }
  return d[a.length][b.length];
}

const minPassword = 8;

String? passwordError(String password, String repeat) {
  if (password.length < minPassword) return 'минимум $minPassword символов';
  if (password != repeat) return 'пароли не совпадают';
  return null;
}

const minUsername = 3;
const maxUsername = 32;

String normalizeUsername(String raw) =>
    raw.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();

final _username = RegExp(r'^[a-z0-9_.]+$');

String? usernameError(String raw) {
  final username = normalizeUsername(raw);
  if (username.length < minUsername) return 'минимум $minUsername символа';
  if (username.length > maxUsername) return 'максимум $maxUsername символа';
  if (!_username.hasMatch(username)) {
    return 'только латиница, цифры, _ и .';
  }
  return null;
}

const minName = 3;
const maxName = 32;

const _emojiRanges = [
  (0x00A9, 0x00A9),
  (0x00AE, 0x00AE),
  (0x203C, 0x203C),
  (0x2049, 0x2049),
  (0x20E3, 0x20E3),
  (0x2122, 0x2122),
  (0x2139, 0x2139),
  (0x2194, 0x21AA),
  (0x231A, 0x23FF),
  (0x24C2, 0x24C2),
  (0x25AA, 0x25FE),
  (0x2600, 0x27BF),
  (0x2934, 0x2935),
  (0x2B05, 0x2B55),
  (0x3030, 0x3030),
  (0x303D, 0x303D),
  (0x3297, 0x3299),
  (0xFE0F, 0xFE0F),
  (0x1F000, 0x1FAFF),
];

bool _hasEmoji(String text) => text.runes.any(
  (rune) => _emojiRanges.any((range) => rune >= range.$1 && rune <= range.$2),
);

String? nameError(String raw) {
  final name = raw.trim();
  if (_hasEmoji(name)) return 'без эмодзи';
  final length = name.characters.length;
  if (length < minName) return 'минимум $minName символа';
  if (length > maxName) return 'максимум $maxName символа';
  return null;
}
