import 'dart:async';

import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/onboarding/auth_flow_source.dart';
import 'package:druna_app/features/onboarding/onboarding_rules.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum OnboardingStep {
  welcome,
  login,
  email,

  signIn,

  code,
  password,
  username,
  name,

  calendar,

  profile,
  done,
}

enum UsernameCheck { idle, checking, available }

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.source,
    required this.onFinished,
    this.onProfile,
    this.knownColorSlot,
    this.knownFont,
    this.calendarSync,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _onText(login, _loginChanged);
    _onText(email, _emailChanged);
    _onText(code, _codeChanged);
    for (final field in [password, repeat, name]) {
      _onText(field, _clearError);
    }
    _onText(signInPassword, _signInPasswordChanged);
    _onText(username, _usernameChanged);
  }

  static void _onText(TextEditingController field, VoidCallback changed) {
    var last = field.text;
    field.addListener(() {
      if (field.text == last) return;
      last = field.text;
      changed();
    });
  }

  final AuthFlowSource source;

  final Future<void> Function() onFinished;

  final void Function(int colorSlot, AvatarFont font)? onProfile;

  final int? knownColorSlot;
  final AvatarFont? knownFont;

  final CalendarSync? calendarSync;

  bool get hasCalendarStep => calendarSync?.supported ?? false;

  final DateTime Function() now;

  static const verifyEmail = false;

  static const verifiedFor = Duration(minutes: 5);

  static const resendAfter = 60;

  static const usernamePause = Duration(milliseconds: 200);

  static const autoSignInPause = Duration(milliseconds: 400);

  static const doneHold = Duration(milliseconds: 3400);

  final login = TextEditingController();
  final email = TextEditingController();
  final code = TextEditingController();
  final signInPassword = TextEditingController();
  final password = TextEditingController();
  final repeat = TextEditingController();
  final username = TextEditingController();
  final name = UpperCaseNameController();

  final loginFocus = FocusNode();
  final emailFocus = FocusNode();
  final codeFocus = FocusNode();
  final signInFocus = FocusNode();
  final passwordFocus = FocusNode();
  final repeatFocus = FocusNode();
  final usernameFocus = FocusNode();
  final nameFocus = FocusNode();

  var _colorSlot = defaultOwnColorSlot;

  var _account = AccountStatus.unknown;

  var _canRegister = false;

  bool get canRegister => _canRegister;

  int get colorSlot => _colorSlot;
  Color get profileColor => avatarPalette[_colorSlot];

  var _font = defaultAvatarFont;
  AvatarFont get profileFont => _font;

  var _colorTurns = 0;
  int get colorTurns => _colorTurns;

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

  List<FocusNode> get stepFocus => switch (_step) {
    OnboardingStep.password => [passwordFocus, repeatFocus],
    _ => [?focus],
  };

  FocusNode? get focus => switch (_step) {
    OnboardingStep.welcome || OnboardingStep.done => null,
    OnboardingStep.login => loginFocus,
    OnboardingStep.email => emailFocus,
    OnboardingStep.signIn => signInFocus,
    OnboardingStep.code => codeFocus,
    OnboardingStep.password => passwordFocus,
    OnboardingStep.username => usernameFocus,
    OnboardingStep.name => nameFocus,
    OnboardingStep.calendar || OnboardingStep.profile => null,
  };

  var _step = OnboardingStep.welcome;
  OnboardingStep get step => _step;

  var _back = false;
  bool get back => _back;

  var _moves = 0;
  int get moves => _moves;

  String? _error;

  String? get error => _error;

  var _errorCount = 0;
  int get errorCount => _errorCount;

  String? _suggestion;
  String? get suggestion => _suggestion;

  var _busy = false;

  bool get busy => _busy;

  String? _codeSentTo;
  DateTime? _verifiedAt;

  bool get _verified =>
      _verifiedAt != null && now().difference(_verifiedAt!) < verifiedFor;

  var _resendLeft = 0;

  int get resendLeft => _resendLeft;
  Timer? _resendTimer;

  var _usernameCheck = UsernameCheck.idle;
  UsernameCheck get usernameCheck => _usernameCheck;
  Timer? _usernameTimer;

  var _usernameRequest = 0;

  Timer? _doneTimer;
  Timer? _autoSignInTimer;
  var _lastSignInPassword = '';
  var _disposed = false;

  bool get canGoBack => switch (_step) {
    OnboardingStep.welcome || OnboardingStep.done => false,
    _ => !_busy,
  };

  bool get canSubmit => switch (_step) {
    OnboardingStep.welcome || OnboardingStep.done => false,
    OnboardingStep.login => usernameError(login.text) == null,
    OnboardingStep.email => looksLikeEmail(email.text),
    OnboardingStep.signIn => signInPassword.text.isNotEmpty,
    OnboardingStep.code => code.text.length == 6,
    OnboardingStep.password =>
      password.text.length >= minPassword && repeat.text.length >= minPassword,
    OnboardingStep.username => _usernameCheck == UsernameCheck.available,
    OnboardingStep.name => name.text.trim().isNotEmpty,
    OnboardingStep.calendar || OnboardingStep.profile => true,
  };

  void start() => _go(OnboardingStep.login);

  void startRegistration() {
    if (_busy) return;
    _canRegister = false;
    _error = null;
    _go(OnboardingStep.email);
  }

  void goBack() {
    if (!canGoBack) return;
    _error = null;
    _suggestion = null;
    _go(switch (_step) {
      OnboardingStep.login => OnboardingStep.welcome,
      OnboardingStep.signIn => OnboardingStep.login,
      OnboardingStep.email =>
        verifyEmail ? OnboardingStep.welcome : OnboardingStep.login,
      OnboardingStep.code => OnboardingStep.email,
      OnboardingStep.password => OnboardingStep.email,
      OnboardingStep.username => OnboardingStep.password,
      OnboardingStep.name =>
        verifyEmail ? OnboardingStep.username : OnboardingStep.password,
      OnboardingStep.calendar => OnboardingStep.name,
      OnboardingStep.profile =>
        hasCalendarStep ? OnboardingStep.calendar : OnboardingStep.name,
      OnboardingStep.welcome || OnboardingStep.done => _step,
    }, back: true);
  }

  Future<void> submit() async {
    if (_busy) return;
    switch (_step) {
      case OnboardingStep.welcome || OnboardingStep.done:
        return;
      case OnboardingStep.login:
        await _submitLogin();
      case OnboardingStep.email:
        if (verifyEmail) {
          await _submitEmail();
        } else {
          _submitRegistrationEmail();
        }
      case OnboardingStep.signIn:
        await _submitSignIn();
      case OnboardingStep.code:
        await _submitCode();
      case OnboardingStep.password:
        final problem = passwordError(password.text, repeat.text);
        if (problem != null) return _fail(problem);
        TextInput.finishAutofillContext();
        if (!verifyEmail) {
          _go(OnboardingStep.name);
          return;
        }
        _go(OnboardingStep.username);
        if (_usernameCheck == UsernameCheck.idle && username.text.isNotEmpty) {
          _scheduleUsernameCheck(Duration.zero);
        }
      case OnboardingStep.username:
        if (_usernameCheck != UsernameCheck.available) {
          final problem = usernameError(username.text);
          if (problem != null) _fail(problem);
          return;
        }
        _go(OnboardingStep.name);
      case OnboardingStep.name:
        final problem = nameError(name.text);
        if (problem != null) return _fail(problem);
        _go(hasCalendarStep ? OnboardingStep.calendar : OnboardingStep.profile);
      case OnboardingStep.calendar:
        _go(OnboardingStep.profile);
      case OnboardingStep.profile:
        await _register();
    }
  }

  void acceptSuggestion() {
    final fixed = _suggestion;
    if (fixed == null) return;
    email.text = fixed;
    email.selection = TextSelection.collapsed(offset: fixed.length);
    _suggestion = null;
    _notify();
  }

  Future<void> forgotPassword() async {
    if (_busy) return;
    await _request(() => source.resetPassword(normalizeEmail(email.text)));
  }

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

  Future<void> _submitLogin() async {
    final problem = usernameError(login.text);
    if (problem != null) return _fail(problem);
    _canRegister = false;
    await _request(() async {
      _account = await source.startUsername(normalizeUsername(login.text));
      _go(
        _account == AccountStatus.fresh
            ? OnboardingStep.email
            : OnboardingStep.signIn,
      );
    });
  }

  void _submitRegistrationEmail() {
    final problem = emailError(email.text);
    if (problem != null) {
      _suggestion = emailSuggestion(email.text);
      return _fail(problem);
    }
    _go(OnboardingStep.password);
  }

  Future<void> _submitEmail() async {
    final problem = emailError(email.text);
    if (problem != null) {
      _suggestion = emailSuggestion(email.text);
      return _fail(problem);
    }
    final address = normalizeEmail(email.text);
    if (address == _codeSentTo) {
      if (_verified) return _go(OnboardingStep.password);
      if (_verifiedAt == null) return _go(OnboardingStep.code);
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
      final String? known;
      try {
        known = await source.signIn(
          username: normalizeUsername(login.text),
          password: signInPassword.text,
        );
      } catch (error) {
        signInPassword.selection = TextSelection(
          baseOffset: 0,
          extentOffset: signInPassword.text.length,
        );
        if (_account == AccountStatus.unknown && isWrongCredentials(error)) {
          _canRegister = true;
          throw wrongLogin;
        }
        rethrow;
      }
      TextInput.finishAutofillContext();
      if (known != null && known.trim().isNotEmpty) name.text = known;
      final slot = knownColorSlot;
      if (slot != null && slot >= 0 && slot < avatarPalette.length) {
        _colorSlot = slot;
      }
      _font = knownFont ?? _font;
      _finish();
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
          username: normalizeUsername(verifyEmail ? username.text : login.text),
          name: name.text.trim(),
        );
      } on AuthTakenException catch (taken) {
        _busy = false;
        if (taken.field == TakenField.email) {
          _codeSentTo = null;
          _verifiedAt = null;
          _go(OnboardingStep.email, back: true);
        } else if (verifyEmail) {
          _usernameCheck = UsernameCheck.idle;
          _go(OnboardingStep.username, back: true);
        } else {
          _go(OnboardingStep.login, back: true);
        }
        _fail(taken.message);
        return;
      }
      TextInput.finishAutofillContext();
      onProfile?.call(_colorSlot, _font);
      _finish();
    });
  }

  void _finish() {
    _go(OnboardingStep.done);
    _doneTimer = Timer(doneHold, () {
      if (!_disposed) onFinished();
    });
  }

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

  void _clearError() {
    _error = null;
    _notify();
  }

  void _signInPasswordChanged() {
    final before = _lastSignInPassword;
    _lastSignInPassword = signInPassword.text;
    _autoSignInTimer?.cancel();
    _clearError();
    if (_step != OnboardingStep.signIn || _busy) return;
    final text = signInPassword.text;
    final added = text.startsWith(before)
        ? text.length - before.length
        : text.length;
    if (added < 2) return;
    _autoSignInTimer = Timer(autoSignInPause, () {
      if (!_disposed && _step == OnboardingStep.signIn) submit();
    });
  }

  void _loginChanged() {
    _canRegister = false;
    _clearError();
  }

  void _emailChanged() {
    _suggestion = null;
    _clearError();
  }

  void _codeChanged() {
    _clearError();
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
    if (normalizeUsername(username.text).length < minUsername) return;
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
      login,
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
      loginFocus,
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
