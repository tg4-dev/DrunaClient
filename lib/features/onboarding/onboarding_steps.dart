import 'package:druna_app/features/onboarding/onboarding_controller.dart';
import 'package:druna_app/features/onboarding/onboarding_style.dart';
import 'package:druna_app/features/onboarding/widgets/code_boxes.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:druna_app/features/onboarding/widgets/onboarding_parts.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/profile_pickers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Where the parts of a step with a field stand. The arrows come first:
/// they are always at least [OnboardingStyle.keyboardClearance] above
/// whatever covers the bottom — the keyboard, or a system sheet in its
/// place such as the strong password one — and without either never lower
/// than [OnboardingStyle.lowest] of the screen. The field sits above them;
/// the title keeps its place near the top while there is room, then moves
/// up, and when even that is not enough the field goes over it and the
/// title fades out.
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
    // A step without a keyboard and with a tall block (the profile) may use
    // the screen down to its bottom edge.
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
    // No room left: the group still ends at the limit, over the title.
    final groupTop =
        titleTop + OnboardingStyle.titleBlock + (free > 0 ? free * 0.5 : free);
    final titleOpacity = free >= 0 ? 1.0 : (1 + free / 40).clamp(0.0, 1.0);
    return StepGeometry._(titleTop, titleOpacity, groupTop, fieldHeight);
  }

  /// The profile (Figma): the title where every step has it, in two
  /// lines; the block right under it; no keyboard, so nothing here follows
  /// one — the step stays put while the name's keyboard goes down. The red
  /// line goes under the block. A short screen lifts it all, then the block
  /// goes over the title.
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

  /// 1, until the field has to go over the title.
  final double titleOpacity;

  /// The top of the red line's slot; the field is under it.
  final double groupTop;
  final double fieldHeight;

  /// Above the field; none on the profile, whose red line is below.
  final double errorSlot;

  /// The field's (the profile block's) top.
  double get fieldTop => groupTop + errorSlot;

  double get navTop =>
      groupTop +
      errorSlot +
      fieldHeight +
      OnboardingStyle.hintSlot +
      OnboardingStyle.navGap;
}

/// The field block's height on [step]: two fields for a new password, the
/// avatar with both pickers on the profile.
double fieldHeightOf(OnboardingStep step) => switch (step) {
  OnboardingStep.password => 2 * OnboardingStyle.height + 10,
  OnboardingStep.profile => ProfileBlock.height,
  _ => OnboardingStyle.height,
};

/// A step with a field: title, red line, field, the hint under it. The
/// arrows are drawn by the flow, so they do not slide with the page.
class FormStepPage extends StatelessWidget {
  const FormStepPage({required this.controller, required this.step, super.key});

  final OnboardingController controller;

  /// Fixed for the page: while it slides out it may rebuild (the keyboard
  /// changes), and must keep its own fields, not grow the next step's.
  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final (title, field, hint) = switch (step) {
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
          // iOS takes only the first hint: «username» offers both saved
          // accounts and the user's own email.
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
        StepTitle(title: 'С возвращением', subtitle: _EmailLine(c.email)),
        _PasswordField(
          fieldKey: const ValueKey('sign-in-password'),
          controller: c.signInPassword,
          focusNode: c.signInFocus,
          hint: 'пароль',
          autofillHint: AutofillHints.password,
          action: TextInputAction.done,
          onSubmitted: c.submit,
        ),
        GestureDetector(
          key: const ValueKey('forgot-password'),
          onTap: c.forgotPassword,
          child: Text('забыл пароль?', style: OnboardingStyle.link),
        ),
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
        StepTitle(title: 'Придумай пароль', subtitle: _EmailLine(c.email)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(
              fieldKey: const ValueKey('password'),
              controller: c.password,
              focusNode: c.passwordFocus,
              hint: 'пароль',
              // «password», not «newPassword»: iOS still pairs it with the
              // email to save, but offers no strong password over the
              // keyboard.
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
              // Out of autofill: nothing is offered in it, and the system
              // saves one password, not two.
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
          // Fixed at the left and dimmed: it is not typed.
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
      OnboardingStep.profile => (
        // «ГЛЕБ, настроим профиль»: the name bold, like everywhere.
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
          tall: step == OnboardingStep.profile,
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
                        // Without a slot above, the red line comes here.
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

/// "00:47".
String _clock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
    '${(seconds % 60).toString().padLeft(2, '0')}';

/// The email under a password's title: plain text, the same as on the
/// code step. Under it lies an invisible read-only field marked as the
/// username, so the system pairs it with the password to save or fill; it
/// takes the text's size and adds no height of its own.
class _EmailLine extends StatelessWidget {
  const _EmailLine(this.email);

  final TextEditingController email;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Text(email.text.trim()),
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: email,
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

  /// Null keeps the field out of autofill.
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
    // A plain keyboard: with «visiblePassword» iOS stops treating the field
    // as a password and offers the email in it.
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

/// Keeps a username typeable: lower case, no spaces, no "@" (the field
/// shows it fixed at the left).
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

/// The profile step's block: room for the avatar, the fonts, the colours
/// (design-system §9.9, §9.11). The avatar itself is drawn by the flow
/// ([ProfileAvatar]): it moves on to the last screen in one piece.
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

/// The user's avatar on the profile step and on the last screen: one
/// widget over both, so it glides and grows from one place to the other
/// instead of fading out and in. It comes in with the profile step, from a
/// little smaller.
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

  /// Where the last screen has the avatar: its centre's height.
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
          curve: Curves.easeOut,
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
