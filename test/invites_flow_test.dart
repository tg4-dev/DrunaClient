import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/event_page/event_page.dart';
import 'package:druna_app/features/settings/settings_page.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A server that knows only the profile: enough for the header and a
  /// rename; everything else runs on the demo data.
  late _ProfileServer server;

  Future<SessionController> pumpPager(
    WidgetTester tester, {
    bool profileLater = false,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    server = _ProfileServer();
    final dio = Dio(
      BaseOptions(baseUrl: 'https://example.test', validateStatus: (_) => true),
    )..httpClientAdapter = server;
    final repository = DrunaRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        tokenStore: MemoryTokenStore(
          const TokenPair(accessToken: 'a', refreshToken: 'r'),
        ),
        dio: dio,
      ),
    );
    final session = SessionController(repository);
    if (!profileLater) await tester.runAsync(session.restore);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePager(
          session: session,
          settings: AppSettings(
            storage: MemorySettingsStorage(),
            demoByDefault: true,
          ),
          config: const AppConfig(
            apiBaseUrl: 'https://example.test',
            environment: 'test',
          ),
          demoDelay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (profileLater) {
      await tester.runAsync(session.restore);
      await tester.pumpAndSettle();
    }
    return session;
  }

  Finder alina() => find.bySemanticsLabel('АЛИНА СМИРНОВА');

  Future<void> holdToday(WidgetTester tester) async {
    final today = DateTime.now();
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(ValueKey('day-${today.year}-${today.month}-${today.day}')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('in friends’ calendar a hold invites the picked friends', (
    tester,
  ) async {
    await pumpPager(tester);
    await tester.tap(alina());
    await tester.pumpAndSettle();

    await holdToday(tester);
    expect(find.byType(EventPage), findsOneWidget);
    expect(find.text('Организатор'), findsOneWidget);
    expect(find.text('Отметить присутствие'), findsOneWidget);
    expect(find.byKey(const ValueKey('description-field')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('sheet-title')), 'Каток');
    await tester.tap(find.byKey(const ValueKey('event-save')));
    await tester.pumpAndSettle();
    expect(find.text('Отправить приглашение?'), findsOneWidget);

    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();
    expect(find.byType(EventPage), findsNothing);

    // On the month a cell of its day, answered (the user organizes it),
    // with the faces and no title; a tap on it opens its page.
    final chip = find.byWidgetPredicate(
      (widget) => widget is SharedCellBack && widget.event.title == 'Каток',
    );
    expect(chip, findsOneWidget);

    await tester.tap(chip, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(EventPage), findsOneWidget);
    expect(find.text('Организатор'), findsOneWidget);
    expect(find.byKey(const ValueKey('event-edit')), findsOneWidget);
    expect(find.text('Вместе с'), findsOneWidget);
    expect(find.text('Ждём'), findsNothing);

    // The organizer always goes: "Нет" only shakes…
    final no = find.byKey(const ValueKey('rsvp-not-going'));
    await tester.tap(no);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Отменить событие?'), findsNothing);

    // …and a second tap soon after calls it off: the page goes, and so
    // does the chip.
    await tester.tap(no);
    await tester.pumpAndSettle();
    expect(find.text('Отменить событие?'), findsOneWidget);
    await tester.tap(find.text('Отменить событие').last);
    await tester.pumpAndSettle();
    expect(find.byType(EventPage), findsNothing);
    expect(find.text('Каток'), findsNothing);
    expect(chip, findsNothing);
  });

  testWidgets('drawing in the open day with friends invites them too', (
    tester,
  ) async {
    await pumpPager(tester);
    await tester.tap(alina());
    await tester.pumpAndSettle();
    final today = DateTime.now();
    await tester.tap(
      find.byKey(ValueKey('day-${today.year}-${today.month}-${today.day}')),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(300, 420));
    await tester.pump(const Duration(milliseconds: 600));
    // Drawn as a dashed outline with everyone's faces while the finger is
    // down, the unanswered cell it will become.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline-ghost')),
        matching: find.byType(FaceStack),
      ),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Отметить присутствие'), findsOneWidget);
  });

  testWidgets('without picked friends a hold makes the user’s own event', (
    tester,
  ) async {
    await pumpPager(tester);
    await holdToday(tester);
    // The event page says it is the user's own (the bar's caption under it
    // says so too).
    expect(
      find.descendant(
        of: find.byType(EventPage),
        matching: find.text('Мои события'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Приглашение'), findsNothing);
  });

  testWidgets('the profile lists invites and answering moves the user', (
    tester,
  ) async {
    await pumpPager(tester);
    await openProfile(tester);

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Ждут ответа · 1'), findsOneWidget);
    final dinner = find.byKey(const ValueKey('invite-row-demo-invite-dinner'));
    expect(
      find.descendant(of: dinner, matching: find.text('Ответить')),
      findsOneWidget,
    );

    await tester.tap(dinner);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(EventPage),
        matching: find.bySemanticsLabel('Ужин у Алины'),
      ),
      findsOneWidget,
    );
    expect(find.text('Готовлю пасту, с вас десерт.'), findsOneWidget);
    // Not answered: the user's avatar waits by the title, not in a row.
    expect(find.byKey(const ValueKey('rsvp-me')), findsOneWidget);
    expect(find.byKey(const ValueKey('face-1')), findsNothing);
    expect(find.byKey(const ValueKey('event-edit')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rsvp-going')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('face-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('rsvp-reset')), findsOneWidget);

    // ✕ takes the answer back, then "Да" again.
    await tester.tap(find.byKey(const ValueKey('rsvp-reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('face-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rsvp-going')));
    await tester.pumpAndSettle();

    // A pull on the top closes the page.
    await tester.fling(
      find.byKey(const ValueKey('event-grabber')),
      const Offset(0, 400),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventPage), findsNothing);
    expect(
      find.descendant(of: dinner, matching: find.text('Иду')),
      findsOneWidget,
    );
  });

  testWidgets('the profile header renames the user', (tester) async {
    final session = await pumpPager(tester);
    await openProfile(tester);
    final field = find.byKey(const ValueKey('profile-name-field'));
    EditableText editable() => tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    String shown() => editable().controller
        .buildTextSpan(context: tester.element(field), withComposing: false)
        .toPlainText();
    // A field in the app's style, not a dialog; the name in capitals, kept
    // as typed (design-system §3).
    expect(editable().controller.text, 'Глеб');
    expect(shown(), 'ГЛЕБ');
    expect(find.text('@gleb'), findsOneWidget);
    // One save for the name and the avatar: nothing to save yet.
    expect(find.byKey(const ValueKey('profile-name-save')), findsNothing);
    expect(find.byKey(const ValueKey('profile-save')), findsNothing);

    // A tap outside ends the editing.
    await tester.tap(field);
    await tester.pump();
    expect(editable().focusNode.hasFocus, isTrue);
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();
    expect(editable().focusNode.hasFocus, isFalse);

    // «Отменить» puts the saved name back.
    await tester.enterText(field, 'Кто-то');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('profile-cancel')));
    await tester.tap(find.byKey(const ValueKey('profile-cancel')));
    await tester.pumpAndSettle();
    expect(editable().controller.text, 'Глеб');
    expect(server.name, 'Глеб');

    await tester.enterText(field, 'Глеб Я.');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-name-save')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(server.name, 'Глеб Я.');
    expect(session.profile?.name, 'Глеб Я.');
    expect(shown(), 'ГЛЕБ Я.');
    expect(find.text('Профиль сохранён'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-save')), findsNothing);
  });

  test('an unanswered invite is see-through on the calendar', () {
    final event = CalendarEvent(
      id: 'x',
      title: '',
      start: DateTime(2026, 11, 2, 18),
      end: DateTime(2026, 11, 2, 19),
      invite: EventInvite(
        id: 'x',
        colors: [Color(0xFF0000FF), Color(0xFFFF0000)],
        pending: true,
      ),
    );
    final fill = eventFill(event, const Color(0xFF00FF00));
    final colors = (fill.gradient! as LinearGradient).colors;
    expect(colors.every((c) => c.a == pendingInviteAlpha), isTrue);
  });

  testWidgets('the user\'s face on shared cells is theirs, also when the '
      'profile comes after the invites', (tester) async {
    final session = await pumpPager(tester, profileLater: true);
    final me = session.profile!;
    final faces = tester
        .widgetList<PersonAvatar>(
          find.descendant(
            of: find.byType(FaceStack),
            matching: find.byType(PersonAvatar),
          ),
        )
        .toList();
    expect(faces, isNotEmpty);
    expect(faces.where((face) => face.id <= 0), isEmpty);
    expect(faces.where((face) => face.id == me.id), isNotEmpty);
  });
}

class _ProfileServer implements HttpClientAdapter {
  var name = 'Глеб';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/users/me')) {
      if (options.method == 'PATCH') {
        final body = options.data is Map
            ? options.data as Map
            : jsonDecode(options.data.toString()) as Map;
        name = body['name']?.toString() ?? name;
      }
      return _json({
        'id': 1,
        'name': name,
        'username': 'gleb',
        'email': 'gleb@example.test',
      });
    }
    return _json(null, status: 404);
  }

  ResponseBody _json(Object? data, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode({
          'data': data,
          'error': status == 200 ? null : {'message': 'нет', 'code': status},
        }),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
