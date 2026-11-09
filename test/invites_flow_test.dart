import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/event_page/event_page.dart';
import 'package:druna_app/features/profile/event_chip.dart';
import 'package:druna_app/features/profile/profile_page.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
          config: const AppConfig(apiBaseUrl: 'https://example.test'),
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

  Finder inProfile(Key key) =>
      find.descendant(of: find.byType(ProfilePage), matching: find.byKey(key));

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
    expect(find.text('Ждём ответа'), findsNothing);

    final no = find.byKey(const ValueKey('rsvp-not-going'));
    await tester.tap(no);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Отменить событие?'), findsNothing);

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

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(inProfile(const ValueKey('profile-label-0')), findsOneWidget);
    expect(
      tester.widget<Text>(inProfile(const ValueKey('profile-label-0'))).data,
      'Ждёт ответа',
    );
    expect(
      tester.widget<Text>(inProfile(const ValueKey('profile-label-1'))).data,
      'Предстоящие',
    );
    final dinner = inProfile(const ValueKey('profile-chip-demo-invite-dinner'));
    expect(tester.widget<EventChip>(dinner).pending, isTrue);

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
    expect(find.byKey(const ValueKey('rsvp-me')), findsOneWidget);
    expect(find.byKey(const ValueKey('face-1')), findsNothing);
    expect(find.byKey(const ValueKey('event-edit')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rsvp-going')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('face-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('rsvp-reset')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rsvp-reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('face-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rsvp-going')));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('event-grabber')),
      const Offset(0, 400),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventPage), findsNothing);
    expect(
      tester.widget<Text>(inProfile(const ValueKey('profile-label-0'))).data,
      'Предстоящие',
    );
    expect(tester.widget<EventChip>(dinner).pending, isFalse);
  });

  testWidgets('the archive slides in with past events and slides back', (
    tester,
  ) async {
    await pumpPager(tester);
    await openProfile(tester);

    final link = inProfile(const ValueKey('profile-archive'));
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();

    await tester.tap(link);
    await tester.pumpAndSettle();
    final picnic = inProfile(const ValueKey('archive-chip-demo-invite-picnic'));
    expect(picnic, findsOneWidget);
    expect(tester.widget<EventChip>(picnic).dimmed, isTrue);
    final nick = find.descendant(
      of: find.byType(ProfilePage),
      matching: find.text('@gleb'),
    );
    expect(tester.getRect(nick).bottom, lessThan(44.0 + 44.0));
    expect(
      tester
          .getRect(
            find.descendant(
              of: find.byType(ProfilePage),
              matching: find.byKey(const ValueKey('profile-edit')),
            ),
          )
          .bottom,
      lessThan(44.0 + 44.0),
    );
    expect(tester.getRect(picnic).left, lessThan(100));

    await tester.tap(inProfile(const ValueKey('archive-back')));
    await tester.pumpAndSettle();
    expect(picnic, findsNothing);
    expect(
      tester.getRect(inProfile(const ValueKey('profile-archive'))).left,
      lessThan(400),
    );
  });

  testWidgets('the profile header renames the user', (tester) async {
    final session = await pumpPager(tester);
    await openProfile(tester);
    expect(find.text('ГЛЕБ'), findsOneWidget);
    expect(find.text('@gleb'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-save')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('profile-name-field'));
    EditableText editable() => tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    String shown() => editable().controller
        .buildTextSpan(context: tester.element(field), withComposing: false)
        .toPlainText();
    expect(editable().controller.text, 'Глеб');
    expect(shown(), 'ГЛЕБ');

    await tester.tap(field);
    await tester.pump();
    expect(editable().focusNode.hasFocus, isTrue);
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();
    expect(editable().focusNode.hasFocus, isFalse);

    await tester.enterText(field, 'Кто-то');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('profile-cancel')));
    await tester.tap(find.byKey(const ValueKey('profile-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-name-field')), findsNothing);
    expect(find.text('ГЛЕБ'), findsOneWidget);
    expect(server.name, 'Глеб');

    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pumpAndSettle();
    expect(editable().controller.text, 'Глеб');
    await tester.enterText(field, 'Глеб Я.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(inProfile(const ValueKey('profile-label-0')), findsNothing);
    }
    await tester.pumpAndSettle();

    expect(server.name, 'Глеб Я.');
    expect(session.profile?.name, 'Глеб Я.');
    expect(find.text('ГЛЕБ Я.'), findsOneWidget);
    expect(find.text('Профиль сохранён'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-save')), findsNothing);
    final label = inProfile(const ValueKey('profile-label-0'));
    expect(tester.widget<Text>(label).data, 'Ждёт ответа');
    final both = find.descendant(
      of: find.byType(ProfilePage),
      matching: find.text('Ждёт ответа'),
    );
    expect(both, findsNWidgets(2));
    expect(
      tester.getRect(both.first).top,
      closeTo(tester.getRect(both.last).top, 0.5),
    );
    expect(
      tester.getRect(label).top,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
  });

  testWidgets('leaving the profile scrolls it back to the top', (tester) async {
    await pumpPager(tester);
    await openProfile(tester);
    final scrollable = find
        .descendant(
          of: find.byType(ProfilePage),
          matching: find.byType(Scrollable),
        )
        .first;
    double offset() =>
        tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(0));
    await tester.flingFrom(const Offset(350, 600), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    await tester.flingFrom(const Offset(50, 600), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(offset(), 0);
  });

  testWidgets('section labels sit on their headings after editing', (
    tester,
  ) async {
    await pumpPager(tester);
    await openProfile(tester);
    final both = find.descendant(
      of: find.byType(ProfilePage),
      matching: find.text('Ждёт ответа'),
    );
    double gap() =>
        tester.getRect(both.first).top - tester.getRect(both.last).top;
    expect(gap(), closeTo(0, 0.5));
    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('profile-cancel')));
    await tester.tap(find.byKey(const ValueKey('profile-cancel')));
    await tester.pumpAndSettle();
    expect(both, findsNWidgets(2));
    expect(gap(), closeTo(0, 0.5));
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
