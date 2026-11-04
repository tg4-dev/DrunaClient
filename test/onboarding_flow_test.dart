import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/druna_app.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/onboarding/auth_flow_source.dart';
import 'package:druna_app/features/onboarding/onboarding_controller.dart';
import 'package:druna_app/features/onboarding/onboarding_flow.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/profile_pickers.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/features/onboarding/widgets/onboarding_parts.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_device_calendar.dart';

void main() {
  group('OnboardingController', () {
    test(
      'a known username goes to the password, a new one to the email',
      () async {
        final flow = _controller(_FakeSource(registered: {'old'}));
        flow.start();
        expect(flow.step, OnboardingStep.login);

        flow.login.text = 'new';
        await flow.submit();
        expect(flow.step, OnboardingStep.email);

        flow.goBack();
        expect(flow.step, OnboardingStep.login);
        flow.login.text = 'old';
        await flow.submit();
        expect(flow.step, OnboardingStep.signIn);
        flow.dispose();
      },
    );

    test('a short username says so on «готово»', () async {
      final flow = _controller(_FakeSource());
      flow.start();
      flow.login.text = 'al';
      expect(flow.canSubmit, isFalse);
      await flow.submit();
      expect(flow.step, OnboardingStep.login);
      expect(flow.error, 'минимум 3 символа');
      flow.dispose();
    });

    test(
      'when the server cannot tell, a wrong password offers to register',
      () async {
        final flow = _controller(_FakeSource(unknown: true));
        flow.start();
        flow.login.text = 'alice';
        await flow.submit();
        expect(flow.step, OnboardingStep.signIn);
        expect(flow.canRegister, isFalse);

        flow.signInPassword.text = 'x';
        await flow.submit();
        expect(flow.error, wrongLogin.message);
        expect(flow.canRegister, isTrue);

        flow.startRegistration();
        expect(flow.step, OnboardingStep.email);
        expect(flow.error, isNull);
        expect(flow.canRegister, isFalse);
        flow.dispose();
      },
    );

    test('a bad email shows the red line and a suggestion', () async {
      final flow = _controller(_FakeSource());
      await _toEmail(flow);
      flow.email.text = 'alice@gmial';
      await flow.submit();
      expect(flow.step, OnboardingStep.email);
      expect(flow.error, 'неверный формат');

      flow.email.text = 'alice@gmial.com';
      await flow.submit();
      expect(flow.error, isNull);
      expect(flow.step, OnboardingStep.password);
      flow.dispose();
    });

    test('steps back and forth keep what was typed', () async {
      final flow = _controller(_FakeSource());
      await _toPassword(flow);
      flow.password.text = 'secret123';
      flow.repeat.text = 'secret123';
      await flow.submit();
      expect(flow.step, OnboardingStep.name);

      flow.goBack();
      expect(flow.step, OnboardingStep.password);
      flow.goBack();
      expect(flow.step, OnboardingStep.email);
      expect(flow.back, isTrue);
      flow.goBack();
      expect(flow.step, OnboardingStep.login);
      expect(flow.login.text, 'alice');
      await flow.submit();
      await flow.submit();
      expect(flow.step, OnboardingStep.password);
      expect(flow.password.text, 'secret123');
      flow.dispose();
    });

    test('password: minimum and repeat', () async {
      final flow = _controller(_FakeSource());
      await _toPassword(flow);
      flow.password.text = 'short';
      flow.repeat.text = 'short';
      await flow.submit();
      expect(flow.error, 'минимум 8 символов');
      flow.password.text = 'secret123';
      flow.repeat.text = 'secret124';
      await flow.submit();
      expect(flow.error, 'пароли не совпадают');
      flow.dispose();
    });

    test('the password arrow lights only from 8 characters', () async {
      final flow = _controller(_FakeSource());
      await _toPassword(flow);
      flow.password.text = 'secret1';
      flow.repeat.text = 'secret1';
      expect(flow.canSubmit, isFalse);
      flow.password.text = 'secret12';
      flow.repeat.text = 'secret12';
      expect(flow.canSubmit, isTrue);
      flow.dispose();
    });

    test('the username check of the email block runs 0.2 s after typing', () {
      fakeAsync((async) {
        final source = _FakeSource();
        final flow = _controller(source);
        flow.username.text = 'ali';
        async.elapse(const Duration(milliseconds: 150));
        flow.username.text = 'alice';
        async.elapse(const Duration(milliseconds: 150));
        expect(source.checked, isEmpty);
        async.elapse(const Duration(milliseconds: 50));
        expect(source.checked, ['alice']);
        expect(flow.usernameCheck, UsernameCheck.available);

        flow.username.text = 'druna';
        async.elapse(OnboardingController.usernamePause);
        expect(flow.usernameCheck, UsernameCheck.idle);
        expect(flow.error, 'ник занят');

        flow.username.text = 'al';
        async.elapse(const Duration(seconds: 2));
        expect(flow.error, isNull);
        expect(source.checked, ['alice', 'druna']);
        flow.dispose();
      });
    });

    test('a late answer for an old username is dropped', () {
      fakeAsync((async) {
        final source = _FakeSource(delay: const Duration(seconds: 1));
        final flow = _controller(source);
        flow.username.text = 'alice';
        async.elapse(const Duration(milliseconds: 1100));
        expect(flow.usernameCheck, UsernameCheck.checking);
        flow.username.text = 'alice2';
        async.elapse(const Duration(milliseconds: 150));
        expect(flow.usernameCheck, UsernameCheck.idle);
        expect(flow.error, isNull);
        flow.dispose();
      });
    });

    test('with a device calendar, its step comes between name and profile', () {
      fakeAsync((async) {
        final storage = MemorySettingsStorage();
        final sync = CalendarSync(
          device: FakeDeviceCalendar(),
          storage: storage,
        );
        sync.load();
        async.flushMicrotasks();
        final flow = OnboardingController(
          source: _FakeSource(),
          onFinished: () async {},
          calendarSync: sync,
        );
        _register(flow, async, name: 'Алиса');
        expect(flow.step, OnboardingStep.calendar);
        expect(flow.canSubmit, isTrue);
        flow.submit();
        expect(flow.step, OnboardingStep.profile);
        flow.goBack();
        expect(flow.step, OnboardingStep.calendar);
        flow.goBack();
        expect(flow.step, OnboardingStep.name);
        flow.dispose();
        sync.dispose();
      });
    });

    test('registers with the typed data, then waits for «Всё готово»', () {
      fakeAsync((async) {
        var finished = 0;
        final source = _FakeSource();
        final flow = OnboardingController(
          source: source,
          onFinished: () async => finished++,
        );
        _register(flow, async, login: 'Alice', email: 'New@Mail.RU');
        expect(flow.step, OnboardingStep.profile);
        flow.submit();
        async.flushMicrotasks();

        expect(flow.step, OnboardingStep.done);
        expect(source.signUps, ['New@mail.ru|alice|Алиса|secret123']);
        expect(finished, 0);
        async.elapse(OnboardingController.doneHold);
        expect(finished, 1);
        flow.dispose();
      });
    });

    test('a taken email or username sends back to its step', () {
      for (final (field, step, text) in [
        (
          TakenField.email,
          OnboardingStep.email,
          'эта почта уже зарегистрирована',
        ),
        (TakenField.username, OnboardingStep.login, 'ник занят'),
      ]) {
        fakeAsync((async) {
          final flow = _controller(_FakeSource(taken: field));
          _register(flow, async);
          flow.submit();
          async.flushMicrotasks();

          expect(flow.step, step);
          expect(flow.error, text);
          expect(flow.busy, isFalse);
          expect(flow.back, isTrue);
          flow.dispose();
        });
      }
    });

    test('other server errors pass through untouched', () {
      const other = ApiException('Нет соединения с сервером.');
      expect(takenOr(other), same(other));
      expect(
        takenOr(const ApiException('duplicate key "unique_email"')),
        isA<AuthTakenException>().having(
          (e) => e.field,
          'field',
          TakenField.email,
        ),
      );
    });

    test('a known username signs in, then «Всё готово» with its avatar', () {
      fakeAsync((async) {
        var finished = 0;
        final source = _FakeSource(registered: {'old'});
        final flow = OnboardingController(
          source: source,
          onFinished: () async => finished++,
          knownColorSlot: 3,
          knownFont: avatarFontById('lobster'),
        );
        flow.start();
        flow.login.text = 'old';
        flow.submit();
        async.flushMicrotasks();
        flow.signInPassword.text = 'wrong';
        flow.submit();
        async.flushMicrotasks();
        expect(flow.error, 'Неверный пароль');
        expect(flow.canRegister, isFalse);
        flow.signInPassword.text = 'secret123';
        flow.submit();
        async.flushMicrotasks();
        expect(flow.step, OnboardingStep.done);
        expect(source.signIns.last, 'old:secret123');
        expect(flow.name.text, 'Аня');
        expect(flow.colorSlot, 3);
        expect(flow.profileFont.id, 'lobster');
        expect(finished, 0);
        async.elapse(OnboardingController.doneHold);
        expect(finished, 1);
        flow.dispose();
      });
    });

    test('a password filled whole signs in by itself, typing does not', () {
      fakeAsync((async) {
        var finished = 0;
        final source = _FakeSource(registered: {'old'});
        final flow = OnboardingController(
          source: source,
          onFinished: () async => finished++,
        );
        flow.start();
        flow.login.text = 'old';
        flow.submit();
        async.flushMicrotasks();
        expect(flow.step, OnboardingStep.signIn);

        for (final letter in 'secret123'.split('')) {
          flow.signInPassword.text += letter;
        }
        async.elapse(const Duration(seconds: 1));
        expect(source.signIns, isEmpty);

        flow.signInPassword.clear();
        flow.signInPassword.text = 'wrong-one';
        async.elapse(const Duration(milliseconds: 300));
        expect(source.signIns, isEmpty);
        async.elapse(const Duration(milliseconds: 200));
        expect(source.signIns, ['old:wrong-one']);
        expect(flow.error, 'Неверный пароль');
        expect(flow.signInPassword.selection.end, 'wrong-one'.length);

        flow.signInPassword.text = 'secret123';
        async.elapse(OnboardingController.autoSignInPause);
        expect(source.signIns, ['old:wrong-one', 'old:secret123']);
        expect(flow.step, OnboardingStep.done);
        async.elapse(OnboardingController.doneHold);
        expect(finished, 1);
        flow.dispose();
      });
    });

    test('a 401 at sign-in reads as a wrong password', () {
      expect(
        authErrorText(const ApiException('bad', statusCode: 401)),
        wrongPassword.message,
      );
      expect(
        isWrongCredentials(const ApiException('bad', statusCode: 401)),
        isTrue,
      );
    });

    test(
      'the server source cannot tell accounts and has no email code',
      () async {
        final source = ServerAuthFlowSource(_repository());
        expect(await source.startUsername('alice'), AccountStatus.unknown);
        await expectLater(
          source.startEmail('a@b.ru'),
          throwsA(emailUnsupported),
        );
        await expectLater(
          source.resetPassword('a@b.ru'),
          throwsA(resetUnsupported),
        );
      },
    );
  });

  group('OnboardingFlow', () {
    testWidgets('welcome: three ways in and the policy card', (tester) async {
      await tester.pumpWidget(_app(_FakeSource()));
      await tester.pumpAndSettle();

      expect(find.text('Найдем время'), findsOneWidget);
      expect(find.text('Войти с Apple'), findsOneWidget);
      expect(find.text('Войти с Google'), findsOneWidget);
      expect(find.text('Вход по нику'), findsOneWidget);

      await tester.tap(find.text('Войти с Apple'));
      await tester.pump();
      expect(find.text('Вход через Apple скоро появится'), findsOneWidget);

      final footnote = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('политикой'),
        ),
      );
      TapGestureRecognizer? link;
      footnote.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
          link = span.recognizer! as TapGestureRecognizer;
        }
        return link == null;
      });
      link!.onTap!();
      await tester.pumpAndSettle();
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
    });

    testWidgets('username → email: autofill, red line, back keeps text', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_FakeSource()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вход по нику'));
      await tester.pumpAndSettle();
      expect(find.text('Введи ник,\nвсё проверим'), findsOneWidget);

      final login = find.byKey(const ValueKey('login-field'));
      expect(
        tester.widget<TextField>(login).autofillHints,
        contains(AutofillHints.username),
      );
      await tester.enterText(login, 'Al');
      await tester.pump();
      expect(find.text('al'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('минимум 3 символа'), findsOneWidget);

      await tester.enterText(login, 'alice');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Введи почту,\nвсё проверим'), findsOneWidget);
      expect(find.byKey(const ValueKey('code-field')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('onboarding-back')));
      await tester.pumpAndSettle();
      expect(find.text('alice'), findsOneWidget);
    });

    testWidgets('a wrong password on the server offers a new account', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_FakeSource(unknown: true)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вход по нику'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('login-field')), 'bob');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('С возвращением'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
      expect(find.byKey(const ValueKey('forgot-password')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('sign-in-password')),
        'x',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('неверный ник или пароль'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('register-instead')));
      await tester.pumpAndSettle();
      expect(find.text('Введи почту,\nвсё проверим'), findsOneWidget);
    });

    testWidgets('the name shows in capitals', (tester) async {
      await tester.pumpWidget(_app(_FakeSource()));
      await tester.pumpAndSettle();
      await _walkToName(tester);
      await tester.enterText(find.byKey(const ValueKey('name-field')), 'Аня');
      await tester.pump();
      final name = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('name-field')),
          matching: find.byType(EditableText),
        ),
      );
      final span = name.controller.buildTextSpan(
        context: tester.element(find.byKey(const ValueKey('name-field'))),
        withComposing: false,
      );
      expect(span.toPlainText(), 'АНЯ');
      expect(name.controller.text, 'Аня');
    });

    testWidgets('the whole path ends in the app', (tester) async {
      var finished = 0;
      (int, AvatarFont)? profile;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(
            source: _FakeSource(),
            onFinished: () async => finished++,
            onProfile: (slot, font) => profile = (slot, font),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _walkToName(tester);
      await tester.enterText(find.byKey(const ValueKey('name-field')), 'Аня');
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      expect(
        find.text('АНЯ,\nнастроим профиль', findRichText: true),
        findsOneWidget,
      );
      AvatarLetter preview() => tester.widget<AvatarLetter>(
        find.descendant(
          of: find.byType(AvatarPreview),
          matching: find.byType(AvatarLetter),
        ),
      );
      expect(preview().letter, 'А');
      expect(
        tester
            .widget<OnboardingBackground>(find.byType(OnboardingBackground))
            .accent,
        defaultOwnColor,
      );
      await tester.tap(find.byKey(const ValueKey('font-lobster')));
      await tester.pumpAndSettle();
      expect(preview().letter, 'а');
      expect(preview().font.id, 'lobster');
      await tester.tap(find.byKey(const ValueKey('color-6')));
      await tester.pumpAndSettle();
      final background = tester.widget<OnboardingBackground>(
        find.byType(OnboardingBackground),
      );
      expect(background.accent, avatarPalette[6]);
      expect(tester.getSize(find.byType(AvatarPreview)).width, 120);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(AvatarPreview), findsOneWidget);
      expect(tester.getSize(find.byType(AvatarPreview)).width, 140);
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('АНЯ, всё готово', findRichText: true), findsOneWidget);
      expect(find.text('пора найти время'), findsOneWidget);
      await tester.pump(OnboardingController.doneHold);
      await tester.pumpAndSettle();
      expect(finished, 1);
      expect(profile?.$1, 6);
      expect(profile?.$2.id, 'lobster');
    });
  });

  testWidgets('every step with a field takes the cursor at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(source: _FakeSource(), onFinished: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    bool focused(String key) =>
        tester.widget<TextField>(find.byKey(ValueKey(key))).focusNode!.hasFocus;

    await tester.tap(find.text('Вход по нику'));
    await tester.pumpAndSettle();
    expect(focused('login-field'), isTrue);
    await tester.enterText(find.byKey(const ValueKey('login-field')), 'alice');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(focused('email-field'), isTrue);
    await tester.enterText(
      find.byKey(const ValueKey('email-field')),
      'alice@mail.ru',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(focused('password'), isTrue);
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret12');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(focused('password-repeat'), isTrue);
    await tester.enterText(
      find.byKey(const ValueKey('password-repeat')),
      'secret12',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(focused('name-field'), isTrue);

    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
    expect(focused('password'), isTrue);
  });

  testWidgets(
    'the repeat of the password keeps the cursor; no autofill in it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(source: _FakeSource(), onFinished: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      await _walkToPassword(tester);

      TextField field(String key) =>
          tester.widget<TextField>(find.byKey(ValueKey(key)));
      expect(field('password').autofillHints, [AutofillHints.password]);
      expect(field('password-repeat').autofillHints, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'secret12',
      );
      await tester.tap(find.byKey(const ValueKey('password-repeat')));
      await tester.pump();
      expect(field('password-repeat').focusNode!.hasFocus, isTrue);
      tester.binding.handleMetricsChanged();
      await tester.pump(const Duration(milliseconds: 400));
      expect(field('password-repeat').focusNode!.hasFocus, isTrue);
      expect(field('password').focusNode!.hasFocus, isFalse);
    },
  );

  testWidgets('a long password fits the field whole', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(source: _FakeSource(), onFinished: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    await _walkToPassword(tester);
    TextField field() =>
        tester.widget<TextField>(find.byKey(const ValueKey('password')));
    expect(tester.getSize(find.byKey(const ValueKey('password'))).width, 300);

    await tester.enterText(
      find.byKey(const ValueKey('password')),
      'kQ2-vbnx7a-Pwe9',
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Показать пароль').first);
    await tester.pump();
    expect(field().style!.fontSize, lessThan(20));
    final painter = TextPainter(
      text: TextSpan(text: 'kQ2-vbnx7a-Pwe9', style: field().style),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, lessThanOrEqualTo(300 - 88));
    painter.dispose();

    await tester.enterText(find.byKey(const ValueKey('password')), 'se');
    await tester.pump();
    expect(field().style!.fontSize, 20);
  });

  testWidgets('a sign-in ends on «Всё готово» with the name', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          source: _FakeSource(registered: {'old'}),
          onFinished: () async => finished++,
          knownColorSlot: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вход по нику'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-field')), 'old');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sign-in-password')),
      'secret123',
    );
    await tester.pump(OnboardingController.autoSignInPause);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('АНЯ, всё готово', findRichText: true), findsOneWidget);
    expect(tester.getSize(find.byType(AvatarPreview)).width, 140);
    final background = tester.widget<OnboardingBackground>(
      find.byType(OnboardingBackground),
    );
    expect(background.accent, avatarPalette[3]);
    expect(finished, 0);
    await tester.pump(OnboardingController.doneHold);
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('the arrows stay above a keyboard or sheet of any height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(source: _FakeSource(), onFinished: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    await _walkToPassword(tester);
    expect(find.text('Придумай пароль'), findsOneWidget);

    for (final covered in [0.0, 336.0, 415.0, 480.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: covered * 3);
      await tester.pumpAndSettle();
      final arrows = tester.getRect(
        find.byKey(const ValueKey('onboarding-next')),
      );
      final top = covered == 0 ? 852 * 0.68 : 852 - covered;
      expect(
        arrows.bottom,
        lessThanOrEqualTo(top - 24 + 0.5),
        reason: '$covered',
      );
    }
  });

  testWidgets('the settings rehearsal plays without the server and closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showOnboardingRehearsal(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Вход по нику'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-close')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  test('the rehearsal source never needs the server', () async {
    final source = RehearsalAuthFlowSource(latency: Duration.zero);
    expect(
      await source.startUsername(RehearsalAuthFlowSource.registeredUsername),
      AccountStatus.registered,
    );
    expect(await source.startUsername('alice'), AccountStatus.fresh);
    await source.register(
      email: 'new@mail.ru',
      password: 'secret12',
      username: 'alice',
      name: 'Аня',
    );
    expect(await source.signIn(username: 'demo', password: 'x'), 'demo');
    await expectLater(
      source.signIn(
        username: 'demo',
        password: RehearsalAuthFlowSource.badPassword,
      ),
      throwsA(wrongPassword),
    );

    final signIn = RehearsalAuthFlowSource(
      signInOnly: true,
      latency: Duration.zero,
    );
    expect(await signIn.startUsername('alice'), AccountStatus.registered);
  });

  testWidgets('«Пройти вход»: any username goes to the password', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showOnboardingRehearsal(context, signIn: true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вход по нику'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-field')), 'anyone');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('С возвращением'), findsOneWidget);
    expect(find.text('@anyone'), findsOneWidget);
  });

  testWidgets('a held button glows; it dies away after release', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PillButton(text: 'Да', onPressed: () {}),
        ),
      ),
    );
    double glow() => tester.widget<PillSurface>(find.byType(PillSurface)).glow;
    expect(glow(), 0);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Да')),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
    expect(glow(), 1);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(glow(), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(glow(), 0);
  });
}

Future<void> _toEmail(OnboardingController flow) async {
  flow.start();
  flow.login.text = 'alice';
  await flow.submit();
}

Future<void> _toPassword(OnboardingController flow) async {
  await _toEmail(flow);
  flow.email.text = 'new@mail.ru';
  await flow.submit();
}

void _register(
  OnboardingController flow,
  FakeAsync async, {
  String login = 'alice',
  String email = 'new@mail.ru',
  String name = '  Алиса ',
}) {
  flow.start();
  flow.login.text = login;
  flow.submit();
  async.flushMicrotasks();
  flow.email.text = email;
  flow.submit();
  flow.password.text = 'secret123';
  flow.repeat.text = 'secret123';
  flow.submit();
  flow.name.text = name;
  flow.submit();
}

Future<void> _walkToPassword(WidgetTester tester) async {
  await tester.tap(find.text('Вход по нику'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('login-field')), 'alice');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('email-field')),
    'alice@mail.ru',
  );
  await tester.testTextInput.receiveAction(TextInputAction.next);
  await tester.pumpAndSettle();
}

Future<void> _walkToName(WidgetTester tester) async {
  await _walkToPassword(tester);
  await tester.enterText(find.byKey(const ValueKey('password')), 'secret12');
  await tester.enterText(
    find.byKey(const ValueKey('password-repeat')),
    'secret12',
  );
  await tester.tap(find.byKey(const ValueKey('onboarding-next')));
  await tester.pumpAndSettle();
}

OnboardingController _controller(AuthFlowSource source) =>
    OnboardingController(source: source, onFinished: () async {});

DrunaRepository _repository() => DrunaRepository(
  ApiClient(
    baseUrl: 'https://example.test',
    tokenStore: MemoryTokenStore(),
    dio: Dio(),
  ),
);

Widget _app(AuthFlowSource source) {
  return DrunaApp(
    repository: _repository(),
    config: const AppConfig(apiBaseUrl: 'https://example.test'),
    authFlowSource: source,
  );
}

class _FakeSource implements AuthFlowSource {
  _FakeSource({
    this.registered = const {},
    this.unknown = false,
    this.delay = Duration.zero,
    this.taken,
  });

  final TakenField? taken;

  final Set<String> registered;
  final bool unknown;
  final Duration delay;
  final checked = <String>[];
  final List<String> signUps = [];
  final List<String> signIns = [];

  Future<void> _wait() =>
      delay == Duration.zero ? Future.value() : Future.delayed(delay);

  @override
  Future<AccountStatus> startUsername(String username) async {
    await _wait();
    if (unknown) return AccountStatus.unknown;
    return registered.contains(username)
        ? AccountStatus.registered
        : AccountStatus.fresh;
  }

  @override
  Future<String?> signIn({
    required String username,
    required String password,
  }) async {
    signIns.add('$username:$password');
    if (password != 'secret123') {
      if (unknown) throw const ApiException('bad', statusCode: 401);
      throw const AuthFlowException('Неверный пароль');
    }
    return 'Аня';
  }

  @override
  Future<EmailStatus> startEmail(String email) async => EmailStatus.fresh;

  @override
  Future<void> resendCode(String email) async {}

  @override
  Future<bool> verifyCode(String email, String code) async => true;

  @override
  Future<bool> usernameAvailable(String username) async {
    checked.add(username);
    await _wait();
    return username != 'druna';
  }

  @override
  Future<void> resetPassword(String email) async => throw resetUnsupported;

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) async {
    if (taken == TakenField.email) {
      throw takenOr(
        const ApiException(
          'pq: duplicate key value violates unique constraint "unique_email"',
        ),
      );
    }
    if (taken == TakenField.username) {
      throw takenOr(
        const ApiException(
          'pq: duplicate key value violates unique constraint '
          '"unique_username"',
        ),
      );
    }
    signUps.add('$email|$username|${name.trim()}|$password');
  }
}
