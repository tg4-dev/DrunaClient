import 'dart:async';

import 'package:druna_app/features/onboarding/auth_flow_source.dart';
import 'package:druna_app/features/onboarding/onboarding_rules.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The screens of the onboarding, in order (design-system §9.9).
enum OnboardingStep {
  welcome,
  email,

  /// The email has an account: its password.
  signIn,

  /// A new email: the code sent to it.
  code,
  password,
  username,
  name,

  /// Profile setup — a placeholder for now.
  profile,
  done,
}

/// The username's availability, shown at the right of its field.
enum UsernameCheck { idle, checking, available }

/// Everything the onboarding has typed and where it is. Fields keep their
/// text when the user steps back and forth.
class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.source,
    required this.onFinished,
    this.onProfile,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _onText(email, _emailChanged);
    _onText(code, _codeChanged);
    for (final field in [password, repeat, name]) {
      _onText(field, _clearError);
    }
    _onText(signInPassword, _signInPasswordChanged);
    _onText(username, _usernameChanged);
  }

  /// Calls [changed] when the text of [field] changes — not its selection,
  /// which also notifies.
  static void _onText(TextEditingController field, VoidCallback changed) {
    var last = field.text;
    field.addListener(() {
      if (field.text == last) return;
      last = field.text;
      changed();
    });
  }

  final AuthFlowSource source;

  /// The tokens are saved and the last screen has played: let the app in.
  final Future<void> Function() onFinished;

  /// The account is made: keep the colour and the font picked on the
  /// profile step ([AppSettings]). Null — nowhere (the rehearsal).
  final void Function(int colorSlot, AvatarFont font)? onProfile;

  /// The clock; tests pass their own.
  final DateTime Function() now;

  /// A confirmed email stays confirmed this long: back on the email and on
  /// again within it, no new code is asked.
  static const verifiedFor = Duration(minutes: 5);

  /// A code may be sent again after this.
  static const resendAfter = 60;

  /// The username is checked this long after the last keystroke.
  static const usernamePause = Duration(milliseconds: 800);

  /// A password that came whole (autofill, paste) signs in after this: the
  /// dots show in the field first.
  static const autoSignInPause = Duration(milliseconds: 400);

  /// How long «Всё готово» stays before the app opens.
  static const doneHold = Duration(milliseconds: 3400);

  final email = TextEditingController();
  final code = TextEditingController();
  final signInPassword = TextEditingController();
  final password = TextEditingController();
  final repeat = TextEditingController();
  final username = TextEditingController();
  final name = UpperCaseNameController();

  /// One per field. The flow moves focus to the new step's field itself:
  /// `autofocus` does nothing while the old field still has it, and the
  /// keyboard would drop between steps.
  final emailFocus = FocusNode();
  final codeFocus = FocusNode();
  final signInFocus = FocusNode();
  final passwordFocus = FocusNode();
  final repeatFocus = FocusNode();
  final usernameFocus = FocusNode();
  final nameFocus = FocusNode();

  var _colorSlot = 0;

  /// The user's colour, a slot of [avatarPalette].
  int get colorSlot => _colorSlot;
  Color get profileColor => avatarPalette[_colorSlot];

  var _font = defaultAvatarFont;
  AvatarFont get profileFont => _font;

  /// Counts the colour changes: the background speeds up on each.
  var _colorTurns = 0;
  int get colorTurns => _colorTurns;

  /// The background's colour: the brand's until the profile step, from
  /// there on the user's.
  Color get backgroundColor =>
      _step.index >= OnboardingStep.profile.index ? profileColor : Brand.accent;

  void pickColor(int slot) {
    if (slot == _colorSlot || slot < 0 || slot >= avatarPalette.length) return;
    _colorSlot = slot;
    _colorTurns++;
    _notify();
  }

  void pickFont(AvatarFont font) {
    if (font.id == _font.id) return;
    _font = font;
    _notify();
  }

  /// Every field of [step]: while one of them has the keyboard, the flow
  /// leaves the focus where the user put it.
  List<FocusNode> get stepFocus => switch (_step) {
    OnboardingStep.password => [passwordFocus, repeatFocus],
    _ => [?focus],
  };

  /// The field that takes the keyboard when [step] opens; null — none.
  FocusNode? get focus => switch (_step) {
    OnboardingStep.welcome || OnboardingStep.done => null,
    OnboardingStep.email => emailFocus,
    OnboardingStep.signIn => signInFocus,
    OnboardingStep.code => codeFocus,
    OnboardingStep.password => passwordFocus,
    OnboardingStep.username => usernameFocus,
    OnboardingStep.name => nameFocus,
    // No keyboard over the pickers.
    OnboardingStep.profile => null,
  };

  var _step = OnboardingStep.welcome;
  OnboardingStep get step => _step;

  /// The last move was back: the screens slide the other way.
  var _back = false;
  bool get back => _back;

  /// Counts the moves; the background speeds up on each.
  var _moves = 0;
  int get moves => _moves;

  String? _error;

  /// The red line above the field.
  String? get error => _error;

  /// Grows with each new error, so the same text shakes again.
  var _errorCount = 0;
  int get errorCount => _errorCount;

  /// A fixed email for a mistyped domain: "может, …@gmail.com?".
  String? _suggestion;
  String? get suggestion => _suggestion;

  var _busy = false;

  /// A request is out: the arrow spins.
  bool get busy => _busy;

  /// The email the code went to, and when the code was entered right.
  String? _codeSentTo;
  DateTime? _verifiedAt;

  bool get _verified =>
      _verifiedAt != null && now().difference(_verifiedAt!) < verifiedFor;

  var _resendLeft = 0;

  /// Seconds until «отправить еще раз».
  int get resendLeft => _resendLeft;
  Timer? _resendTimer;

  var _usernameCheck = UsernameCheck.idle;
  UsernameCheck get usernameCheck => _usernameCheck;
  Timer? _usernameTimer;

  /// Which check is current: an answer to an older one is dropped.
  var _usernameRequest = 0;

  Timer? _doneTimer;
  Timer? _autoSignInTimer;
  var _lastSignInPassword = '';
  var _disposed = false;

  bool get canGoBack => switch (_step) {
    OnboardingStep.welcome || OnboardingStep.done => false,
    _ => !_busy,
  };

  /// The forward arrow is lit.
  bool get canSubmit => switch (_step) {
    OnboardingStep.welcome || OnboardingStep.done => false,
    OnboardingStep.email => looksLikeEmail(email.text),
    OnboardingStep.signIn => signInPassword.text.isNotEmpty,
    OnboardingStep.code => code.text.length == 6,
    OnboardingStep.password =>
      password.text.length >= minPassword && repeat.text.length >= minPassword,
    OnboardingStep.username => _usernameCheck == UsernameCheck.available,
    OnboardingStep.name => name.text.trim().isNotEmpty,
    OnboardingStep.profile => true,
  };

  /// «Вход по Email» on the welcome screen.
  void start() => _go(OnboardingStep.email);

  void goBack() {
    if (!canGoBack) return;
    _error = null;
    _suggestion = null;
    _go(switch (_step) {
      OnboardingStep.email => OnboardingStep.welcome,
      OnboardingStep.signIn || OnboardingStep.code => OnboardingStep.email,
      // A confirmed code is done with: back goes to the email.
      OnboardingStep.password => OnboardingStep.email,
      OnboardingStep.username => OnboardingStep.password,
      OnboardingStep.name => OnboardingStep.username,
      OnboardingStep.profile => OnboardingStep.name,
      OnboardingStep.welcome || OnboardingStep.done => _step,
    }, back: true);
  }

  /// The forward arrow, or the keyboard's return.
  Future<void> submit() async {
    if (_busy) return;
    switch (_step) {
      case OnboardingStep.welcome || OnboardingStep.done:
        return;
      case OnboardingStep.email:
        await _submitEmail();
      case OnboardingStep.signIn:
        await _submitSignIn();
      case OnboardingStep.code:
        await _submitCode();
      case OnboardingStep.password:
        final problem = passwordError(password.text, repeat.text);
        if (problem != null) return _fail(problem);
        // The email and the new password: the system may offer to save.
        TextInput.finishAutofillContext();
        _go(OnboardingStep.username);
        // Coming back with a username already typed: check it at once.
        if (_usernameCheck == UsernameCheck.idle && username.text.isNotEmpty) {
          _scheduleUsernameCheck(Duration.zero);
        }
      case OnboardingStep.username:
        if (_usernameCheck != UsernameCheck.available) return;
        _go(OnboardingStep.name);
      case OnboardingStep.name:
        final problem = nameError(name.text);
        if (problem != null) return _fail(problem);
        _go(OnboardingStep.profile);
      case OnboardingStep.profile:
        await _register();
    }
  }

  /// Takes the "может, …?" suggestion.
  void acceptSuggestion() {
    final fixed = _suggestion;
    if (fixed == null) return;
    email.text = fixed;
    email.selection = TextSelection.collapsed(offset: fixed.length);
    _suggestion = null;
    _notify();
  }

  /// «забыл пароль?» under the sign-in password.
  Future<void> forgotPassword() async {
    if (_busy) return;
    await _request(() => source.resetPassword(normalizeEmail(email.text)));
  }

  /// «отправить еще раз».
  Future<void> resend() async {
    final to = _codeSentTo;
    if (_resendLeft > 0 || _busy || to == null) return;
    await _request(() async {
      await source.resendCode(to);
      code.clear();
      _error = null;
      _startResendTimer();
    });
  }

  Future<void> _submitEmail() async {
    final problem = emailError(email.text);
    if (problem != null) {
      _suggestion = emailSuggestion(email.text);
      return _fail(problem);
    }
    final address = normalizeEmail(email.text);
    if (address == _codeSentTo) {
      // Confirmed less than [verifiedFor] ago: straight to the password.
      if (_verified) return _go(OnboardingStep.password);
      // Sent but not entered yet: the same code, no second letter.
      if (_verifiedAt == null) return _go(OnboardingStep.code);
      // Confirmed too long ago: a new code below.
    }
    await _request(() async {
      final status = await source.startEmail(address);
      if (status == EmailStatus.registered) {
        _go(OnboardingStep.signIn);
        return;
      }
      _codeSentTo = address;
      _verifiedAt = null;
      code.clear();
      _startResendTimer();
      _go(OnboardingStep.code);
    });
  }

  Future<void> _submitSignIn() async {
    if (signInPassword.text.isEmpty) return;
    await _request(() async {
      try {
        await source.signIn(
          email: normalizeEmail(email.text),
          password: signInPassword.text,
        );
      } catch (_) {
        // The next input replaces the password, as with a wrong code.
        signInPassword.selection = TextSelection(
          baseOffset: 0,
          extentOffset: signInPassword.text.length,
        );
        rethrow;
      }
      // The system may now offer to save the email and password.
      TextInput.finishAutofillContext();
      await onFinished();
    });
  }

  Future<void> _submitCode() async {
    final to = _codeSentTo;
    if (code.text.length != 6 || to == null) return;
    if (_verified) return _go(OnboardingStep.password);
    await _request(() async {
      final right = await source.verifyCode(to, code.text);
      if (!right) {
        code.selection = TextSelection(
          baseOffset: 0,
          extentOffset: code.text.length,
        );
        return _fail('проверь еще раз');
      }
      _verifiedAt = now();
      _go(OnboardingStep.password);
    });
  }

  Future<void> _register() async {
    await _request(() async {
      try {
        await source.register(
          email: _codeSentTo ?? normalizeEmail(email.text),
          password: password.text,
          username: normalizeUsername(username.text),
          name: name.text.trim(),
        );
      } on AuthTakenException catch (taken) {
        // Back to the step with the taken value, the red line on it.
        _busy = false;
        if (taken.field == TakenField.email) {
          _codeSentTo = null;
          _verifiedAt = null;
          _go(OnboardingStep.email, back: true);
        } else {
          _usernameCheck = UsernameCheck.idle;
          _go(OnboardingStep.username, back: true);
        }
        _fail(taken.message);
        return;
      }
      TextInput.finishAutofillContext();
      onProfile?.call(_colorSlot, _font);
      _go(OnboardingStep.done);
      _doneTimer = Timer(doneHold, () {
        if (!_disposed) onFinished();
      });
    });
  }

  /// Runs [action] with the arrow spinning; a failure becomes the red line.
  Future<void> _request(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
    } catch (error) {
      if (_disposed) return;
      _busy = false;
      _fail(authErrorText(error));
      return;
    }
    if (_disposed) return;
    _busy = false;
    _notify();
  }

  void _go(OnboardingStep step, {bool back = false}) {
    if (step == _step) return;
    _autoSignInTimer?.cancel();
    _step = step;
    _back = back;
    _moves++;
    if (!back) _error = null;
    _notify();
  }

  void _fail(String message) {
    _error = message;
    _errorCount++;
    HapticFeedback.heavyImpact();
    _notify();
  }

  /// Typing clears the red line; the arrow may light up.
  void _clearError() {
    _error = null;
    _notify();
  }

  /// A password that appears whole at once — the system filled it or it
  /// was pasted — signs in by itself; typing letter by letter does not.
  void _signInPasswordChanged() {
    final before = _lastSignInPassword;
    _lastSignInPassword = signInPassword.text;
    _autoSignInTimer?.cancel();
    _clearError();
    if (_step != OnboardingStep.signIn || _busy) return;
    // Pasted or filled over the old text too, after a wrong password.
    final text = signInPassword.text;
    final added = text.startsWith(before)
        ? text.length - before.length
        : text.length;
    if (added < 2) return;
    _autoSignInTimer = Timer(autoSignInPause, () {
      if (!_disposed && _step == OnboardingStep.signIn) submit();
    });
  }

  void _emailChanged() {
    _suggestion = null;
    _clearError();
  }

  void _codeChanged() {
    _clearError();
    // The sixth digit sends the code by itself.
    if (_step == OnboardingStep.code && code.text.length == 6) submit();
  }

  void _usernameChanged() {
    _usernameRequest++;
    _usernameTimer?.cancel();
    _usernameCheck = UsernameCheck.idle;
    _error = null;
    if (username.text.isNotEmpty) _scheduleUsernameCheck(usernamePause);
    _notify();
  }

  void _scheduleUsernameCheck(Duration after) {
    _usernameTimer?.cancel();
    _usernameTimer = Timer(after, _checkUsername);
  }

  Future<void> _checkUsername() async {
    final problem = usernameError(username.text);
    if (problem != null) return _fail(problem);
    final request = ++_usernameRequest;
    _usernameCheck = UsernameCheck.checking;
    _notify();
    try {
      final free = await source.usernameAvailable(
        normalizeUsername(username.text),
      );
      if (_disposed || request != _usernameRequest) return;
      _usernameCheck = free ? UsernameCheck.available : UsernameCheck.idle;
      if (free) {
        HapticFeedback.selectionClick();
        _notify();
      } else {
        _fail('ник занят');
      }
    } catch (error) {
      if (_disposed || request != _usernameRequest) return;
      _usernameCheck = UsernameCheck.idle;
      _fail(authErrorText(error));
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendLeft = resendAfter;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _resendLeft--;
      if (_resendLeft <= 0) {
        _resendLeft = 0;
        timer.cancel();
      }
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _resendTimer?.cancel();
    _usernameTimer?.cancel();
    _doneTimer?.cancel();
    _autoSignInTimer?.cancel();
    for (final field in [
      email,
      code,
      signInPassword,
      password,
      repeat,
      username,
      name,
    ]) {
      field.dispose();
    }
    for (final node in [
      emailFocus,
      codeFocus,
      signInFocus,
      passwordFocus,
      repeatFocus,
      usernameFocus,
      nameFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }
}
