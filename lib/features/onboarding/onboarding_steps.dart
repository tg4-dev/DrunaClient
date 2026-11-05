import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:druna_app/features/onboarding/onboarding_controller.dart';
import 'package:druna_app/features/onboarding/onboarding_style.dart';
import 'package:druna_app/features/onboarding/widgets/code_boxes.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:druna_app/features/onboarding/widgets/onboarding_parts.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/profile_pickers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StepGeometry {
  StepGeometry._(
    this.titleTop,
    this.titleOpacity,
    this.groupTop,
    this.fieldHeight, {
    this.errorSlot = OnboardingStyle.errorSlot,
  });

  factory StepGeometry.of(
    BuildContext context,
    Size size, {
    required double fieldHeight,
    bool tall = false,
  }) {
    final media = MediaQuery.of(context);
    if (tall) return StepGeometry._tall(media, size, fieldHeight);
    final covered = media.viewInsets.bottom;
    final lowest = tall
        ? size.height - media.padding.bottom
        : size.height * OnboardingStyle.lowest;
    final bottom = (size.height - covered).clamp(0, lowest).toDouble();
    final limit = bottom - OnboardingStyle.keyboardClearance;
    final group = groupHeight(fieldHeight);
    var titleTop = media.padding.top + OnboardingStyle.titleTop;
    var free = limit - (titleTop + OnboardingStyle.titleBlock) - group;
    if (free < 16) {
      final up = (16 - free)
          .clamp(0, titleTop - media.padding.top - 12)
          .toDouble();
      titleTop -= up;
      free += up;
    }
    final groupTop =
        titleTop + OnboardingStyle.titleBlock + (free > 0 ? free * 0.5 : free);
    final titleOpacity = free >= 0 ? 1.0 : (1 + free / 40).clamp(0.0, 1.0);
    return StepGeometry._(titleTop, titleOpacity, groupTop, fieldHeight);
  }

  factory StepGeometry._tall(MediaQueryData media, Size size, double block) {
    var titleTop = media.padding.top + OnboardingStyle.titleTop;
    const below =
        OnboardingStyle.hintSlot +
        OnboardingStyle.navGap +
        OnboardingStyle.height;
    final limit =
        size.height - media.padding.bottom - OnboardingStyle.keyboardClearance;
    var groupTop = titleTop + OnboardingStyle.profileTitle;
    final over = groupTop + block + below - limit;
    var titleOpacity = 1.0;
    if (over > 0) {
      final up = over.clamp(0, titleTop - media.padding.top - 12).toDouble();
      titleTop -= up;
      groupTop -= over;
      final left = over - up;
      titleOpacity = (1 - left / 40).clamp(0.0, 1.0);
    }
    return StepGeometry._(
      titleTop,
      titleOpacity,
      groupTop,
      block,
      errorSlot: 0,
    );
  }

  static double groupHeight(double fieldHeight) =>
      OnboardingStyle.errorSlot +
      fieldHeight +
      OnboardingStyle.hintSlot +
      OnboardingStyle.navGap +
      OnboardingStyle.height;

  final double titleTop;

  final double titleOpacity;

  final double groupTop;
  final double fieldHeight;

  final double errorSlot;

  double get fieldTop => groupTop + errorSlot;

  double get navTop =>
      groupTop +
      errorSlot +
      fieldHeight +
      OnboardingStyle.hintSlot +
      OnboardingStyle.navGap;
}

bool tallStep(OnboardingStep step) =>
    step == OnboardingStep.profile || step == OnboardingStep.calendar;

double fieldHeightOf(OnboardingStep step) => switch (step) {
  OnboardingStep.password => 2 * OnboardingStyle.height + 10,
  OnboardingStep.profile => ProfileBlock.height,
  OnboardingStep.calendar => CalendarBlock.height,
  _ => OnboardingStyle.height,
};

class FormStepPage extends StatelessWidget {
  const FormStepPage({required this.controller, required this.step, super.key});

  final OnboardingController controller;

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final (title, field, hint) = switch (step) {
      OnboardingStep.login => (
        const StepTitle(title: 'Введи ник,\nвсё проверим'),
        PillField(
          fieldKey: const ValueKey('login-field'),
          controller: c.login,
          focusNode: c.loginFocus,
          hint: 'nickname',
          keyboardType: TextInputType.visiblePassword,
          autofillHints: const [AutofillHints.username],
          inputFormatters: const [UsernameFormatter()],
          onSubmitted: c.submit,
          leading: Text(
            '@',
            style: OnboardingStyle.field.copyWith(
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
        null,
      ),
      OnboardingStep.email => (
        const StepTitle(title: 'Введи почту,\nвсё проверим'),
        PillField(
          fieldKey: const ValueKey('email-field'),
          controller: c.email,
          hint: 'example@mail.com',
          width: OnboardingStyle.emailWidth,
          style: OnboardingStyle.emailField,
          hintStyle: OnboardingStyle.emailHint,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          focusNode: c.emailFocus,
          onSubmitted: c.submit,
        ),
        c.suggestion == null
            ? null
            : GestureDetector(
                key: const ValueKey('email-suggestion'),
                onTap: c.acceptSuggestion,
                child: Text(
                  'может, ${c.suggestion}?',
                  style: OnboardingStyle.link,
                ),
              ),
      ),
      OnboardingStep.signIn => (
        StepTitle(
          title: 'С возвращением',
          subtitle: _LoginLine(c.login, prefix: '@'),
        ),
        _PasswordField(
          fieldKey: const ValueKey('sign-in-password'),
          controller: c.signInPassword,
          focusNode: c.signInFocus,
          hint: 'пароль',
          autofillHint: AutofillHints.password,
          action: TextInputAction.done,
          onSubmitted: c.submit,
        ),
        c.canRegister
            ? GestureDetector(
                key: const ValueKey('register-instead'),
                onTap: c.startRegistration,
                child: Text(
                  'создать аккаунт с этим ником',
                  style: OnboardingStyle.link,
                ),
              )
            : OnboardingController.verifyEmail
            ? GestureDetector(
                key: const ValueKey('forgot-password'),
                onTap: c.forgotPassword,
                child: Text('забыл пароль?', style: OnboardingStyle.link),
              )
            : null,
      ),
      OnboardingStep.code => (
        StepTitle(
          title: 'Отправили код на',
          subtitle: Text(c.email.text.trim()),
        ),
        CodeBoxes(
          controller: c.code,
          focusNode: c.codeFocus,
          onSubmitted: c.submit,
        ),
        c.resendLeft > 0
            ? Text(
                'попробуем еще через ${_clock(c.resendLeft)}',
                style: OnboardingStyle.hint,
              )
            : GestureDetector(
                key: const ValueKey('resend'),
                onTap: c.resend,
                child: Text('отправить еще раз', style: OnboardingStyle.link),
              ),
      ),
      OnboardingStep.password => (
        StepTitle(title: 'Придумай пароль', subtitle: _LoginLine(c.email)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(
              fieldKey: const ValueKey('password'),
              controller: c.password,
              focusNode: c.passwordFocus,
              hint: 'пароль',
              autofillHint: AutofillHints.password,
              action: TextInputAction.next,
              onSubmitted: c.repeatFocus.requestFocus,
            ),
            const SizedBox(height: 10),
            _PasswordField(
              fieldKey: const ValueKey('password-repeat'),
              controller: c.repeat,
              focusNode: c.repeatFocus,
              hint: 'еще раз',
              autofillHint: null,
              action: TextInputAction.done,
              onSubmitted: c.submit,
            ),
          ],
        ),
        Text('минимум 8 символов', style: OnboardingStyle.hint),
      ),
      OnboardingStep.username => (
        const StepTitle(
          title: 'Давай знакомиться',
          subtitle: Text('установим твой ник'),
        ),
        PillField(
          fieldKey: const ValueKey('username-field'),
          controller: c.username,
          focusNode: c.usernameFocus,
          hint: 'nickname',
          keyboardType: TextInputType.visiblePassword,
          autofillHints: const [AutofillHints.newUsername],
          inputFormatters: const [UsernameFormatter()],
          onSubmitted: c.submit,
          leading: Text(
            '@',
            style: OnboardingStyle.field.copyWith(
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          trailing: switch (c.usernameCheck) {
            UsernameCheck.idle => null,
            UsernameCheck.checking => const CupertinoActivityIndicator(
              key: ValueKey('username-checking'),
              color: Colors.white,
            ),
            UsernameCheck.available => const Icon(
              CupertinoIcons.checkmark_alt,
              key: ValueKey('username-available'),
              color: OnboardingStyle.success,
              size: 24,
            ),
          },
        ),
        null,
      ),
      OnboardingStep.name => (
        const StepTitle(
          title: 'А теперь имя',
          subtitle: Text('его будут видеть друзья'),
        ),
        PillField(
          fieldKey: const ValueKey('name-field'),
          controller: c.name,
          hint: 'ИМЯ',
          width: null,
          style: OnboardingStyle.nameField,
          hintStyle: OnboardingStyle.nameHint,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
          focusNode: c.nameFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: c.submit,
        ),
        null,
      ),
      OnboardingStep.calendar => (
        Text(
          'Подключим\nтвой календарь',
          textAlign: TextAlign.center,
          style: OnboardingStyle.title,
          maxLines: 2,
        ),
        CalendarBlock(sync: c.calendarSync!),
        ListenableBuilder(
          listenable: c.calendarSync!,
          builder: (context, _) => Text(
            c.calendarSync!.connected
                ? 'можно поменять в календаре'
                : 'можно подключить позже',
            style: OnboardingStyle.hint,
          ),
        ),
      ),
      OnboardingStep.profile => (
        NameText(
          parts: [shownName(c.name.text), ',\nнастроим профиль'],
          names: const {0},
          style: OnboardingStyle.title,
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
        ProfileBlock(controller: c),
        null,
      ),
      OnboardingStep.welcome || OnboardingStep.done => (
        const SizedBox.shrink(),
        const SizedBox.shrink(),
        null,
      ),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final at = StepGeometry.of(
          context,
          constraints.biggest,
          fieldHeight: fieldHeightOf(step),
          tall: tallStep(step),
        );
        return Stack(
          children: [
            Positioned(
              top: at.titleTop,
              left: 24,
              right: 24,
              height: OnboardingStyle.titleBlock,
              child: Opacity(
                opacity: at.titleOpacity,
                child: Align(alignment: Alignment.topCenter, child: title),
              ),
            ),
            Positioned(
              top: at.groupTop,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (at.errorSlot > 0)
                    ErrorShake(
                      error: c.error,
                      count: c.errorCount,
                      child: field,
                    )
                  else
                    field,
                  SizedBox(
                    height: OnboardingStyle.hintSlot,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: OnboardingStyle.fade,
                        child: at.errorSlot == 0 && c.error != null
                            ? Text(
                                c.error!,
                                key: ValueKey(c.error),
                                textAlign: TextAlign.center,
                                style: OnboardingStyle.error,
                              )
                            : hint ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _clock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
    '${(seconds % 60).toString().padLeft(2, '0')}';

class _LoginLine extends StatelessWidget {
  const _LoginLine(this.login, {this.prefix = ''});

  final TextEditingController login;
  final String prefix;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Text('$prefix${login.text.trim()}'),
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: login,
                readOnly: true,
                showCursor: false,
                enableInteractiveSelection: false,
                autofillHints: const [AutofillHints.username],
                style: OnboardingStyle.subtitle,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.autofillHint,
    required this.action,
    required this.focusNode,
    this.onSubmitted,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String hint;

  final String? autofillHint;
  final TextInputAction action;
  final FocusNode focusNode;
  final VoidCallback? onSubmitted;
  final Key? fieldKey;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  var _hidden = true;

  @override
  Widget build(BuildContext context) => PillField(
    fieldKey: widget.fieldKey,
    controller: widget.controller,
    hint: widget.hint,
    focusNode: widget.focusNode,
    obscure: _hidden,
    width: OnboardingStyle.emailWidth,
    fitText: true,
    keyboardType: TextInputType.text,
    autofillHints: [?widget.autofillHint],
    textInputAction: widget.action,
    onSubmitted: widget.onSubmitted,
    trailing: Semantics(
      button: true,
      label: _hidden ? 'Показать пароль' : 'Скрыть пароль',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _hidden = !_hidden),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            _hidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            color: Colors.white.withValues(alpha: 0.6),
            size: 20,
          ),
        ),
      ),
    ),
  );
}

class UsernameFormatter extends TextInputFormatter {
  const UsernameFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('@', '')
        .toLowerCase();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class ProfileBlock extends StatelessWidget {
  const ProfileBlock({required this.controller, super.key});

  final OnboardingController controller;

  static const avatar = 120.0;
  static const avatarGap = 40.0;
  static const pickerGap = 28.0;
  static const height =
      avatar +
      avatarGap +
      ProfilePickerStyle.fontHeight +
      pickerGap +
      2 * ProfilePickerStyle.colorCell +
      2 * ProfilePickerStyle.colorInset;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: avatar + avatarGap),
          FontPicker(
            name: c.name.text,
            selected: c.profileFont,
            onPick: c.pickFont,
          ),
          const SizedBox(height: pickerGap),
          ColorPicker(selected: c.colorSlot, onPick: c.pickColor),
        ],
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.controller,
    required this.size,
    super.key,
  });

  final OnboardingController controller;
  final Size size;

  static const done = 140.0;
  static const glide = Duration(milliseconds: 650);

  static double doneCentre(Size size) => size.height * 0.40;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final step = c.step;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shown = step == OnboardingStep.profile || step == OnboardingStep.done;
    final atDone = step == OnboardingStep.done;
    final profileTop = StepGeometry.of(
      context,
      size,
      fieldHeight: ProfileBlock.height,
      tall: true,
    ).fieldTop;
    final diameter = atDone ? done : ProfileBlock.avatar;
    final top = atDone ? doneCentre(size) - done / 2 : profileTop;
    final duration = reduce ? Duration.zero : glide;
    return AnimatedPositioned(
      duration: duration,
      curve: Curves.easeInOutCubic,
      top: top,
      left: (size.width - diameter) / 2,
      width: diameter,
      height: diameter,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: reduce ? Duration.zero : OnboardingStyle.move,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: shown ? 1 : 0.85,
            duration: reduce ? Duration.zero : OnboardingStyle.move,
            curve: Curves.easeOutCubic,
            child: LayoutBuilder(
              builder: (context, box) => AvatarPreview(
                color: c.profileColor,
                font: c.profileFont,
                name: c.name.text.trim().isEmpty ? '?' : c.name.text,
                size: box.maxWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarBlock extends StatelessWidget {
  const CalendarBlock({required this.sync, super.key});

  final CalendarSync sync;

  static const rows = 6;

  static const gutter = 24.0;
  static const row = OnboardingStyle.height;
  static const inset = ProfilePickerStyle.colorInset;
  static const height = rows * row + 2 * inset;

  static const _dot = 12.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListenableBuilder(
      listenable: sync,
      builder: (context, _) => AnimatedSwitcher(
        duration: OnboardingStyle.fade,
        child: sync.connected
            ? _list()
            : sync.access == CalendarAccess.denied
            ? _pitch(
                key: const ValueKey('calendar-denied'),
                text: 'Доступ закрыт. Его можно дать в настройках',
                button: PillButton(
                  key: const ValueKey('calendar-settings'),
                  icon: CupertinoIcons.gear_alt,
                  text: 'Открыть настройки',
                  height: OnboardingStyle.height,
                  onPressed: sync.openSettings,
                ),
              )
            : _pitch(
                key: const ValueKey('calendar-ask'),
                text:
                    'Покажем события из ${_where()} рядом с твоими, '
                    'а свои добавим в календарь «Druna»',
                button: PillButton(
                  key: const ValueKey('calendar-allow'),
                  icon: CupertinoIcons.calendar,
                  text: 'Разрешить доступ',
                  height: OnboardingStyle.height,
                  onPressed: sync.connect,
                ),
              ),
      ),
    ),
  );

  String _where() => deviceCalendarName() == 'Apple Календарь'
      ? 'Apple Календаря'
      : 'календаря устройства';

  Widget _pitch({
    required Key key,
    required String text,
    required Widget button,
  }) => Center(
    key: key,
    child: SizedBox(
      width: ProfilePickerStyle.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center, style: OnboardingStyle.hint),
          const SizedBox(height: 16),
          button,
        ],
      ),
    ),
  );

  Widget _list() => Padding(
    key: const ValueKey('calendar-list'),
    padding: const EdgeInsets.symmetric(horizontal: gutter),
    child: SizedBox(
      height: height,
      child: PillSurface(
        radius: ProfilePickerStyle.colorRadius,
        child: sync.calendars.isEmpty
            ? Center(
                child: Text(
                  sync.syncing ? 'загружаем…' : 'календарей нет',
                  style: OnboardingStyle.hint,
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: inset),
                children: [
                  for (final calendar in sync.calendars)
                    _CalendarRow(
                      key: ValueKey('calendar-${calendar.id}'),
                      calendar: calendar,
                      on: sync.isOn(calendar.id),
                      onChanged: (on) => sync.setCalendar(calendar.id, on),
                    ),
                ],
              ),
      ),
    ),
  );
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({
    required this.calendar,
    required this.on,
    required this.onChanged,
    super.key,
  });

  final DeviceCalendarInfo calendar;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: CalendarBlock.row,
    child: Padding(
      padding: const EdgeInsets.only(left: 20, right: 12),
      child: Row(
        children: [
          Container(
            width: CalendarBlock._dot,
            height: CalendarBlock._dot,
            decoration: BoxDecoration(
              color: calendar.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  calendar.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OnboardingStyle.calendarName,
                ),
                if (calendar.account.isNotEmpty)
                  Text(
                    calendar.account,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OnboardingStyle.calendarAccount,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AdaptiveSwitch(value: on, onChanged: onChanged),
        ],
      ),
    ),
  );
}
