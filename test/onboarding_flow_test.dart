import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/druna_app.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
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

void main() {
  group('OnboardingController', () {
    test('a new email goes to the code, a known one to the password', () async {
      final source = _FakeSource(registered: {'old@mail.ru'});
      final flow = _controller(source);
      flow.start();

      flow.email.text = 'new@mail.ru';
      await flow.submit();
      expect(flow.step, OnboardingStep.code);
      expect(source.codesSent, ['new@mail.ru']);
      expect(flow.resendLeft, OnboardingController.resendAfter);

      flow.goBack();
      flow.email.text = 'old@mail.ru';
      await flow.submit();
      expect(flow.step, OnboardingStep.signIn);
      flow.dispose();
    });

    test('a bad email shows the red line and a suggestion', () async {
      final flow = _controller(_FakeSource());
      flow.start();
      flow.email.text = 'alice@gmial';
      await flow.submit();
      expect(flow.step, OnboardingStep.email);
      expect(flow.error, 'неверный формат');

      flow.email.text = 'alice@gmial.com';
      await flow.submit();
      expect(flow.error, isNull);
      // A valid address with a typo goes on: the suggestion is only shown
      // for a refused one.
      expect(flow.step, OnboardingStep.code);
      flow.dispose();
    });

    test(
      'a wrong code keeps the digits selected; the sixth digit sends',
      () async {
        final flow = _controller(_FakeSource());
        flow.start();
        flow.email.text = 'new@mail.ru';
        await flow.submit();

        flow.code.text = '111111';
        await pumpEventQueue();
        expect(flow.error, 'проверь еще раз');
        expect(flow.code.selection.start, 0);
        expect(flow.code.selection.end, 6);
        expect(flow.step, OnboardingStep.code);

        flow.code.text = '123456';
        await pumpEventQueue();
        expect(flow.step, OnboardingStep.password);
        flow.dispose();
      },
    );

    test('steps back and forth keep what was typed, no second code', () async {
      final source = _FakeSource();
      final flow = _controller(source);
      flow.start();
      flow.email.text = 'new@mail.ru';
      await flow.submit();
      flow.code.text = '123456';
      await pumpEventQueue();
      flow.password.text = 'secret123';
      flow.repeat.text = 'secret123';
      await flow.submit();
      expect(flow.step, OnboardingStep.username);

      flow.goBack();
      expect(flow.step, OnboardingStep.password);
      // The confirmed code is done with: back skips it.
      flow.goBack();
      expect(flow.step, OnboardingStep.email);
      expect(flow.back, isTrue);
      await flow.submit();
      expect(flow.step, OnboardingStep.password);
      expect(flow.password.text, 'secret123');
      expect(source.codesSent, hasLength(1));
      flow.dispose();
    });

    test('a confirmed email holds for 5 minutes, then a new code', () async {
      var time = DateTime(2026, 11, 2, 12);
      final source = _FakeSource();
      final flow = OnboardingController(
        source: source,
        onFinished: () async {},
        now: () => time,
      );
      await _toPassword(flow);
      expect(flow.step, OnboardingStep.password);

      flow.goBack();
      time = time.add(const Duration(minutes: 4, seconds: 59));
      await flow.submit();
      expect(flow.step, OnboardingStep.password);
      expect(source.codesSent, hasLength(1));

      flow.goBack();
      time = time.add(const Duration(minutes: 1));
      await flow.submit();
      expect(flow.step, OnboardingStep.code);
      expect(source.codesSent, hasLength(2));
      expect(flow.code.text, isEmpty);
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

    test('the code may be sent again after a minute', () {
      fakeAsync((async) {
        final source = _FakeSource();
        final flow = _controller(source);
        flow.start();
        flow.email.text = 'new@mail.ru';
        flow.submit();
        async.flushMicrotasks();
        flow.resend();
        async.flushMicrotasks();
        expect(source.resent, 0);

        async.elapse(const Duration(seconds: 60));
        expect(flow.resendLeft, 0);
        flow.resend();
        async.flushMicrotasks();
        expect(source.resent, 1);
        expect(flow.resendLeft, OnboardingController.resendAfter);
        flow.dispose();
      });
    });

    test('the username is checked 0.8 s after typing stops', () {
      fakeAsync((async) {
        final source = _FakeSource();
        final flow = _controller(source);
        flow.username.text = 'ali';
        async.elapse(const Duration(milliseconds: 500));
        flow.username.text = 'alice';
        async.elapse(const Duration(milliseconds: 700));
        expect(source.checked, isEmpty);
        async.elapse(const Duration(milliseconds: 100));
        expect(source.checked, ['alice']);
        expect(flow.usernameCheck, UsernameCheck.available);

        flow.username.text = 'druna';
        async.elapse(OnboardingController.usernamePause);
        expect(flow.usernameCheck, UsernameCheck.idle);
        expect(flow.error, 'ник занят');

        flow.username.text = 'al';
        async.elapse(OnboardingController.usernamePause);
        expect(flow.error, 'минимум 3 символа');
        expect(source.checked, ['alice', 'druna']);
        flow.dispose();
      });
    });

    test('a late answer for an old username is dropped', () {
      fakeAsync((async) {
        final source = _FakeSource(delay: const Duration(seconds: 1));
        final flow = _controller(source);
        flow.username.text = 'alice';
        async.elapse(const Duration(milliseconds: 1300));
        expect(flow.usernameCheck, UsernameCheck.checking);
        flow.username.text = 'alice2';
        // The answer for "alice" arrives now and is dropped; the check of
        // "alice2" has not started yet.
        async.elapse(const Duration(milliseconds: 600));
        expect(flow.usernameCheck, UsernameCheck.idle);
        expect(flow.error, isNull);
        flow.dispose();
      });
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

    test('registers with the typed data, then waits for «Всё готово»', () {
      fakeAsync((async) {
        var finished = 0;
        final source = _FakeSource();
        final flow = OnboardingController(
          source: source,
          onFinished: () async => finished++,
        );
        flow.start();
        flow.email.text = 'New@Mail.RU';
        flow.submit();
        async.flushMicrotasks();
        flow.code.text = '123456';
        async.flushMicrotasks();
        flow.password.text = 'secret123';
        flow.repeat.text = 'secret123';
        flow.submit();
        flow.username.text = 'alice';
        async.elapse(OnboardingController.usernamePause);
        flow.submit();
        flow.name.text = '  Алиса ';
        flow.submit();
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

    test('the server\'s taken email or username sends back to that step', () {
      for (final (field, step, text) in [
        (
          TakenField.email,
          OnboardingStep.email,
          'эта почта уже зарегистрирована',
        ),
        (TakenField.username, OnboardingStep.username, 'ник занят'),
      ]) {
        fakeAsync((async) {
          final flow = _controller(_FakeSource(taken: field));
          flow.start();
          flow.email.text = 'new@mail.ru';
          flow.submit();
          async.flushMicrotasks();
          flow.code.text = '123456';
          async.flushMicrotasks();
          flow.password.text = 'secret123';
          flow.repeat.text = 'secret123';
          flow.submit();
          flow.username.text = 'alice';
          async.elapse(OnboardingController.usernamePause);
          flow.submit();
          flow.name.text = 'Алиса';
          flow.submit();
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

    test('a known email signs in with its password', () async {
      var finished = 0;
      final source = _FakeSource(registered: {'old@mail.ru'});
      final flow = OnboardingController(
        source: source,
        onFinished: () async => finished++,
      );
      flow.start();
      flow.email.text = 'old@mail.ru';
      await flow.submit();
      flow.signInPassword.text = 'wrong';
      await flow.submit();
      expect(flow.error, 'Неверный пароль');
      flow.signInPassword.text = 'secret123';
      await flow.submit();
      expect(finished, 1);
      flow.dispose();
    });

    test('a password filled whole signs in by itself, typing does not', () {
      fakeAsync((async) {
        var finished = 0;
        final source = _FakeSource(registered: {'old@mail.ru'});
        final flow = OnboardingController(
          source: source,
          onFinished: () async => finished++,
        );
        flow.start();
        flow.email.text = 'old@mail.ru';
        flow.submit();
        async.flushMicrotasks();
        expect(flow.step, OnboardingStep.signIn);

        // Letter by letter: nothing is sent.
        for (final letter in 'secret123'.split('')) {
          flow.signInPassword.text += letter;
        }
        async.elapse(const Duration(seconds: 1));
        expect(source.signIns, isEmpty);

        // Filled whole, the wrong one: sent after the pause, then selected.
        flow.signInPassword.clear();
        flow.signInPassword.text = 'wrong-one';
        async.elapse(const Duration(milliseconds: 300));
        expect(source.signIns, isEmpty);
        async.elapse(const Duration(milliseconds: 200));
        expect(source.signIns, ['wrong-one']);
        expect(flow.error, 'Неверный пароль');
        expect(flow.signInPassword.selection.end, 'wrong-one'.length);

        // Filled again over the selection: in.
        flow.signInPassword.text = 'secret123';
        async.elapse(OnboardingController.autoSignInPause);
        expect(source.signIns, ['wrong-one', 'secret123']);
        expect(finished, 1);
        flow.dispose();
      });
    });

    test('«забыл пароль?» says honestly it is not supported', () async {
      final flow = _controller(_FakeSource(registered: {'old@mail.ru'}));
      flow.start();
      flow.email.text = 'old@mail.ru';
      await flow.submit();
      await flow.forgotPassword();
      expect(flow.error, resetUnsupported.message);
      expect(flow.step, OnboardingStep.signIn);
      flow.dispose();
    });

    test('a 401 at sign-in reads as a wrong password', () {
      expect(
        authErrorText(const ApiException('bad', statusCode: 401)),
        wrongPassword.message,
      );
    });

    test('the server source says honestly what it cannot do', () async {
      final source = ServerAuthFlowSource(_repository());
      await expectLater(
        source.startEmail('a@b.ru'),
        throwsA(isA<AuthFlowException>()),
      );
      final flow = _controller(source);
      flow.start();
      flow.email.text = 'a@b.ru';
      await flow.submit();
      expect(flow.error, 'Вход по почте пока не поддерживается сервером');
      expect(flow.step, OnboardingStep.email);
      flow.dispose();
    });

    test('the demo remembers emails registered on this device', () async {
      final storage = MemorySettingsStorage();
      final source = DemoAuthFlowSource(
        repository: _repository(),
        storage: storage,
        latency: Duration.zero,
      );
      expect(await source.startEmail('a@b.ru'), EmailStatus.fresh);
      expect(await source.verifyCode('a@b.ru', '000000'), isFalse);
      expect(
        await source.verifyCode('a@b.ru', DemoAuthFlowSource.code),
        isTrue,
      );
      expect(await source.usernameAvailable('druna'), isFalse);
      storage.values['demo_auth.accounts'] = '{"a@b.ru":"alice"}';
      expect(await source.startEmail('a@b.ru'), EmailStatus.registered);
    });
  });

  group('OnboardingFlow', () {
    testWidgets('welcome: three ways in and the policy card', (tester) async {
      await tester.pumpWidget(_app(_FakeSource()));
      await tester.pumpAndSettle();

      expect(find.text('Найдем время'), findsOneWidget);
      expect(find.text('Войти с Apple'), findsOneWidget);
      expect(find.text('Войти с Google'), findsOneWidget);
      expect(find.text('Вход по Email'), findsOneWidget);

      await tester.tap(find.text('Войти с Apple'));
      await tester.pump();
      expect(find.text('Вход через Apple скоро появится'), findsOneWidget);

      // The link is a span of the footnote: its recogniser is the tap.
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

    testWidgets('email → code: autofill hints, red line, back keeps text', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_FakeSource()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вход по Email'));
      await tester.pumpAndSettle();
      expect(find.text('Введи почту,\nотправим код'), findsOneWidget);

      final email = find.byKey(const ValueKey('email-field'));
      expect(
        tester.widget<TextField>(email).autofillHints,
        contains(AutofillHints.username),
      );
      await tester.enterText(email, 'alice@mail');
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('неверный формат'), findsOneWidget);

      await tester.enterText(email, 'alice@mail.ru');
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Отправили код на'), findsOneWidget);
      expect(find.text('попробуем еще через 01:00'), findsOneWidget);
      final code = tester.widget<TextField>(
        find.byKey(const ValueKey('code-field')),
      );
      expect(code.autofillHints, [AutofillHints.oneTimeCode]);
      expect(code.keyboardType, TextInputType.number);
      // The cursor is in the code at once.
      expect(code.focusNode!.hasFocus, isTrue);

      await tester.tap(find.byKey(const ValueKey('onboarding-back')));
      await tester.pumpAndSettle();
      expect(find.text('alice@mail.ru'), findsOneWidget);
    });

    testWidgets('a wrong code says so; the right one moves on', (tester) async {
      await tester.pumpWidget(_app(_FakeSource()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вход по Email'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-field')),
        'alice@mail.ru',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      final code = find.byKey(const ValueKey('code-field'));
      await tester.enterText(code, '647322');
      await tester.pumpAndSettle();
      expect(find.text('проверь еще раз'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      await tester.enterText(code, '123456');
      await tester.pumpAndSettle();
      expect(find.text('Придумай пароль'), findsOneWidget);
    });

    testWidgets('username: spinner, then a green tick; name in capitals', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_FakeSource(delay: const Duration(milliseconds: 300))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вход по Email'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-field')),
        'alice@mail.ru',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('code-field')),
        '123456',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'secret12',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password-repeat')),
        'secret12',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('username-field')),
        'Alice',
      );
      await tester.pump();
      expect(find.text('alice'), findsOneWidget);
      // "@" stands fixed at the left of the field, not in the text.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('username-field')),
          matching: find.text('@'),
        ),
        findsNothing,
      );
      expect(find.text('@'), findsOneWidget);
      await tester.pump(OnboardingController.usernamePause);
      await tester.pump();
      expect(find.byKey(const ValueKey('username-checking')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('username-available')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
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

    testWidgets('the whole demo path ends in the app', (tester) async {
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
      await tester.tap(find.text('Вход по Email'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-field')),
        'alice@mail.ru',
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('code-field')),
        '123456',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'secret12',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password-repeat')),
        'secret12',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('username-field')),
        'alice',
      );
      await tester.pump(OnboardingController.usernamePause);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('name-field')), 'Аня');
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      // The name in the title, bold; the avatar with both pickers.
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
      // One avatar for both screens: on the profile it is 120 …
      expect(tester.getSize(find.byType(AvatarPreview)).width, 120);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // … and it has grown to 140 on the last screen, not faded and back.
      expect(find.byType(AvatarPreview), findsOneWidget);
      expect(tester.getSize(find.byType(AvatarPreview)).width, 140);
      expect(finished, 0);
      // The avatar lands, then the name rises in under it.
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

    await tester.tap(find.text('Вход по Email'));
    await tester.pumpAndSettle();
    expect(focused('email-field'), isTrue);
    await tester.enterText(
      find.byKey(const ValueKey('email-field')),
      'alice@mail.ru',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(focused('code-field'), isTrue);
    await tester.enterText(find.byKey(const ValueKey('code-field')), '123456');
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
    expect(focused('username-field'), isTrue);
    await tester.enterText(find.byKey(const ValueKey('username-field')), 'al1');
    await tester.pump(OnboardingController.usernamePause);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(focused('name-field'), isTrue);

    // Back keeps the keyboard too: the username field takes it again.
    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
    expect(focused('username-field'), isTrue);
    expect(find.text('al1'), findsOneWidget);
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
      await tester.tap(find.text('Вход по Email'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-field')),
        'alice@mail.ru',
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('code-field')),
        '123456',
      );
      await tester.pumpAndSettle();

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
      // The keyboard changes (iOS swaps it for the other field): the check
      // that keeps the keyboard up must not pull the cursor back.
      tester.binding.handleMetricsChanged();
      await tester.pump(const Duration(milliseconds: 400));
      expect(field('password-repeat').focusNode!.hasFocus, isTrue);
      expect(field('password').focusNode!.hasFocus, isFalse);
    },
  );

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
    await tester.tap(find.text('Вход по Email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email-field')),
      'alice@mail.ru',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('code-field')), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Придумай пароль'), findsOneWidget);

    // The strong password sheet: about 415 pt of a 852 pt screen.
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
    expect(find.text('Вход по Email'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-close')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  test('the rehearsal source never needs the server', () async {
    final source = RehearsalAuthFlowSource(latency: Duration.zero);
    expect(
      await source.startEmail(RehearsalAuthFlowSource.registeredEmail),
      EmailStatus.registered,
    );
    expect(await source.startEmail('new@mail.ru'), EmailStatus.fresh);
    await source.register(
      email: 'new@mail.ru',
      password: 'secret12',
      username: 'alice',
      name: 'Аня',
    );
    await source.signIn(email: 'demo@druna.app', password: 'x');
    await expectLater(
      source.signIn(
        email: 'demo@druna.app',
        password: RehearsalAuthFlowSource.badPassword,
      ),
      throwsA(wrongPassword),
    );
    await expectLater(
      source.resetPassword('demo@druna.app'),
      throwsA(resetUnsupported),
    );

    final signIn = RehearsalAuthFlowSource(
      signInOnly: true,
      latency: Duration.zero,
    );
    expect(await signIn.startEmail('new@mail.ru'), EmailStatus.registered);
  });

  testWidgets('«Пройти вход»: any email goes to the password', (tester) async {
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
    await tester.tap(find.text('Вход по Email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email-field')),
      'anyone@mail.ru',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('С возвращением'), findsOneWidget);
    expect(find.byKey(const ValueKey('forgot-password')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forgot-password')));
    await tester.pumpAndSettle();
    expect(find.text(resetUnsupported.message), findsOneWidget);
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
    // The tap is recognised after the press timeout, then the glow runs.
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

Future<void> _toPassword(OnboardingController flow) async {
  flow.start();
  flow.email.text = 'new@mail.ru';
  await flow.submit();
  flow.code.text = '123456';
  await pumpEventQueue();
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
  final store = MemoryTokenStore();
  return DrunaApp(
    repository: DrunaRepository(
      ApiClient(baseUrl: 'https://example.test', tokenStore: store, dio: Dio()),
    ),
    tokenStore: store,
    config: const AppConfig(
      apiBaseUrl: 'https://example.test',
      environment: 'test',
    ),
    authFlowSource: source,
  );
}

class _FakeSource implements AuthFlowSource {
  _FakeSource({
    this.registered = const {},
    this.delay = Duration.zero,
    this.taken,
  });

  /// Registration refuses this field, as the server does.
  final TakenField? taken;

  final Set<String> registered;
  final Duration delay;
  final codesSent = <String>[];
  final checked = <String>[];
  final List<String> signUps = [];
  var resent = 0;

  Future<void> _wait() =>
      delay == Duration.zero ? Future.value() : Future.delayed(delay);

  @override
  Future<EmailStatus> startEmail(String email) async {
    await _wait();
    if (registered.contains(email)) return EmailStatus.registered;
    codesSent.add(email);
    return EmailStatus.fresh;
  }

  @override
  Future<void> resendCode(String email) async => resent++;

  @override
  Future<bool> verifyCode(String email, String code) async {
    await _wait();
    return code == '123456';
  }

  @override
  Future<bool> usernameAvailable(String username) async {
    checked.add(username);
    await _wait();
    return username != 'druna';
  }

  final List<String> signIns = [];

  @override
  Future<void> signIn({required String email, required String password}) async {
    signIns.add(password);
    if (password != 'secret123') {
      throw const AuthFlowException('Неверный пароль');
    }
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
    signUps.add('$email|$username|$name|$password');
  }
}
