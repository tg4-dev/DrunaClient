import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_repeat_block.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/event_page/attendance_block.dart';
import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/features/event_page/event_span.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:druna_app/features/event_page/event_subject.dart';
import 'package:druna_app/features/event_page/fit_title.dart';
import 'package:druna_app/features/event_page/picker_scope.dart';
import 'package:druna_app/features/event_page/repeat_summary.dart';
import 'package:druna_app/features/event_page/when_block.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Every event in one form (design-system §9.1, §9.8): the user's own, an
/// invite being made, and an invite that exists. A sheet rises from the
/// bottom over an animated gradient; the top pulls it down. It shows the
/// event, and the pencil turns it into its editor.
///
/// Own events: a pull down while editing saves at once, as before.
/// Invites go out or change only by ✓, after a question; a pull only
/// closes them.
class EventPage extends StatefulWidget {
  const EventPage({
    required this.subject,
    required this.me,
    required this.onGone,
    this.invites,
    this.onSave,
    this.onDelete,
    this.onSendInvite,
    this.onClosing,
    super.key,
  });

  final EventSubject subject;

  /// The user: their answer, whether they organize, their avatar.
  final FriendInfo me;

  /// The store a [SharedInvite] lives in.
  final InvitesStore? invites;

  /// An own event was saved; the page may stay open on it.
  final ValueChanged<CalendarEvent>? onSave;

  /// An own event (with its series) is to be removed.
  final VoidCallback? onDelete;

  /// Sends a [NewInvite]; throws if it failed, and the page stays.
  final Future<void> Function(InviteDraft draft)? onSendInvite;

  /// The page starts leaving: the calendar may take touches again.
  final VoidCallback? onClosing;

  /// The page has left and can be removed.
  final VoidCallback onGone;

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> with TickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: EventPageStyle.enter,
    reverseDuration: EventPageStyle.leave,
  );
  late final CurvedAnimation _rise = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutQuart,
    reverseCurve: Curves.easeInCubic,
  );
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: EventPageStyle.settle,
  )..addListener(_onSettle);
  final _drag = ValueNotifier<double>(0);
  double _settleFrom = 0;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _titleFocus = FocusNode();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _pickers = PickerScope();

  late bool _editing;
  var _closing = false;
  var _busy = false;

  /// The own event as last saved; the page shows it.
  CalendarEvent? _event;
  late EventSpan _span;
  RepeatRule? _repeat;

  /// The user's answer before the store has it, so the page answers at
  /// once; dropped when the store agrees or the call fails.
  RsvpStatus? _answer;

  /// The last known shared invite, kept to play the exit after it is gone.
  Invite? _last;

  @override
  void initState() {
    super.initState();
    switch (widget.subject) {
      case OwnEvent(:final event, :final isNew):
        _event = event;
        _editing = isNew;
        _load(event, title: event.title, repeat: event.repeat);
      case NewInvite(:final event):
        _editing = true;
        _load(event, title: event.title);
      case SharedInvite():
        _editing = false;
        _last = _shared;
        widget.invites?.addListener(_onStore);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _motion.forward();
      if (_editing) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.invites?.removeListener(_onStore);
    _rise.dispose();
    _motion.dispose();
    _settle.dispose();
    _drag.dispose();
    _titleFocus.dispose();
    _title.dispose();
    _description.dispose();
    _pickers.dispose();
    super.dispose();
  }

  void _load(
    CalendarEvent event, {
    required String title,
    String description = '',
    RepeatRule? repeat,
  }) {
    _span = EventSpan.of(event);
    _title.text = title;
    _description.text = description;
    _repeat = repeat;
  }

  Invite? get _shared => switch (widget.subject) {
    SharedInvite(:final id) => widget.invites?.byId(id),
    _ => null,
  };

  /// The invite on screen: the shared one, or the one being made, with the
  /// user as its organizer.
  Invite? get _invite => switch (widget.subject) {
    OwnEvent() => null,
    NewInvite(:final invitees) => Invite(
      id: 'draft',
      organizer: widget.me,
      title: _title.text,
      description: _description.text,
      start: _span.start,
      end: _span.end,
      allDay: _span.allDay,
      participants: [
        for (final person in invitees)
          InviteParticipant(person, RsvpStatus.pending),
      ],
    ),
    SharedInvite() => _shared ?? _last,
  };

  bool get _own => widget.subject is OwnEvent;

  bool get _organizer => _invite?.isOrganizer(widget.me.id) ?? true;

  bool get _canEdit => _own || _organizer;

  void _onStore() {
    final invite = _shared;
    if (invite == null) {
      // Called off, here or elsewhere: the page goes.
      if (_last != null) _close();
      return;
    }
    _last = invite;
    if (_answer == invite.statusOf(widget.me.id)) _answer = null;
    setState(() {});
  }

  // Motion

  void _onSettle() {
    final t = Curves.easeOutCubic.transform(_settle.value);
    _drag.value = _settleFrom * (1 - t);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _settle.stop();
    final next = _drag.value + (details.primaryDelta ?? 0);
    // Upward pulls resist; the sheet only leaves downward.
    _drag.value = next < 0 ? next * 0.25 : next;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_drag.value > EventPageStyle.dismissDistance ||
        velocity > EventPageStyle.dismissVelocity) {
      _swipeAway();
      return;
    }
    _settleFrom = _drag.value;
    _settle.forward(from: 0);
  }

  /// Saves an own event being edited the moment the finger lifts, then
  /// slides out fast while the calendar already takes touches.
  void _swipeAway() {
    _closing = true;
    _dropKeyboard();
    final event = _event;
    if (_own && _editing && event != null) widget.onSave?.call(_draft(event));
    widget.onClosing?.call();
    final height = MediaQuery.sizeOf(context).height;
    final from = _drag.value;
    final exit = AnimationController(
      vsync: this,
      duration: EventPageStyle.fling,
    );
    final curve = CurvedAnimation(parent: exit, curve: Curves.easeOutCubic);
    exit.addListener(() => _drag.value = from + (height - from) * curve.value);
    exit.forward().whenComplete(() {
      curve.dispose();
      exit.dispose();
      if (mounted) widget.onGone();
    });
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _dropKeyboard();
    widget.onClosing?.call();
    await _motion.reverse();
    if (mounted) widget.onGone();
  }

  void _toast(Object error) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Не получилось. Попробуй ещё раз.',
          ),
        ),
      );
  }

  // Editing

  CalendarEvent _draft(CalendarEvent event) =>
      _span.applyTo(event, title: _title.text, repeat: _repeat);

  InviteDraft _inviteDraft(List<FriendInfo> invitees) => InviteDraft(
    title: _title.text.trim(),
    description: _description.text.trim(),
    start: _span.start,
    end: _span.end,
    allDay: _span.allDay,
    invitees: invitees,
  );

  void _edit() {
    final invite = _invite;
    if (invite != null) {
      _load(
        CalendarEvent(
          id: invite.id,
          title: invite.title,
          start: invite.start,
          end: invite.end,
          allDay: invite.allDay,
        ),
        title: invite.title,
        description: invite.description,
      );
    } else if (_event case final event?) {
      _load(event, title: event.title, repeat: event.repeat);
    }
    HapticFeedback.selectionClick();
    setState(() => _editing = true);
  }

  /// ✓: own events save and show; a new invite asks, sends and closes; a
  /// shared one asks, saves and shows.
  Future<void> _confirm() async {
    if (_busy) return;
    _dropKeyboard();
    switch (widget.subject) {
      case OwnEvent():
        final saved = _draft(_event!);
        widget.onSave?.call(saved);
        setState(() {
          _event = saved;
          _editing = false;
        });
      case NewInvite(:final invitees):
        final ok = await confirmAction(
          context,
          title: 'Отправить приглашение?',
          message:
              'Позовём: ${peopleLabel(invitees)}. '
              'Они увидят приглашение в Druna.',
          confirmLabel: 'Отправить',
        );
        if (!ok || !mounted) return;
        final sent = await _run(
          () => widget.onSendInvite!(_inviteDraft(invitees)),
        );
        if (sent) _close();
      case SharedInvite(:final id):
        final invite = _invite;
        if (invite == null) return;
        final ok = await confirmAction(
          context,
          title: 'Сохранить изменения?',
          message: 'Участники увидят новое время и описание.',
          confirmLabel: 'Сохранить',
        );
        if (!ok || !mounted) return;
        final saved = await _run(
          () => widget.invites!.update(
            id,
            _inviteDraft([
              for (final participant in invite.participants) participant.person,
            ]),
          ),
        );
        if (saved && mounted) setState(() => _editing = false);
    }
  }

  /// Whatever field has the keyboard — the title or the description —
  /// lets it go; otherwise it stays on screen after the page is gone.
  void _dropKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  /// 🗑: removes an own event, drops a new invite, calls a shared one off.
  Future<void> _delete() async {
    if (_busy) return;
    _dropKeyboard();
    switch (widget.subject) {
      case OwnEvent(:final isNew):
        if (!isNew) {
          final ok = await confirmAction(
            context,
            title: 'Удалить событие?',
            message: _event?.repeat != null || _event?.seriesId != null
                ? 'Удалятся все его повторы.'
                : 'Вернуть его не получится.',
            confirmLabel: 'Удалить',
            destructive: true,
          );
          if (!ok || !mounted) return;
        }
        widget.onDelete?.call();
        _close();
      case NewInvite():
        _close();
      case SharedInvite():
        await _cancelInvite();
    }
  }

  Future<void> _cancelInvite() async {
    if (widget.subject is NewInvite) {
      _close();
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Отменить событие?',
      message: 'Оно пропадёт у всех участников.',
      confirmLabel: 'Отменить событие',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final subject = widget.subject;
    if (subject is SharedInvite) {
      await _run(() => widget.invites!.cancel(subject.id));
    }
  }

  /// Runs [action] with the buttons off; false and a toast if it failed.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) _toast(error);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(RsvpStatus status) async {
    final subject = widget.subject;
    if (subject is! SharedInvite || _busy) return;
    HapticFeedback.selectionClick();
    setState(() => _answer = status);
    try {
      await widget.invites!.respond(subject.id, status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _answer = null);
      _toast(error);
    }
  }

  // Building

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    if (!_own && invite == null) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final top = media.padding.top + EventPageStyle.top;
    return IgnorePointer(
      ignoring: _closing,
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: AnimatedBuilder(
            animation: Listenable.merge([_rise, _drag]),
            builder: (context, sheet) {
              final drag = _drag.value;
              final release = (1 - drag.clamp(0, 400) / 400).toDouble();
              return Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: (_rise.value * release).clamp(0.0, 1.0),
                      child: const ColoredBox(color: EventPageStyle.scrim),
                    ),
                  ),
                  Positioned.fill(
                    top: top,
                    child: Transform.translate(
                      offset: Offset(0, height * (1 - _rise.value) + drag),
                      child: sheet,
                    ),
                  ),
                ],
              );
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(EventPageStyle.radius),
              ),
              // White caret, handles and selection over any gradient.
              child: Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: const TextSelectionThemeData(
                    cursorColor: Colors.white,
                    selectionColor: Color(0x55FFFFFF),
                    selectionHandleColor: Colors.white,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: EventGradient(colors: _colors(invite)),
                    ),
                    Positioned.fill(child: _content(invite, media)),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: EventPageStyle.handleZone,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: _onDragUpdate,
                        onVerticalDragEnd: _onDragEnd,
                        child: const Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: _Grabber(key: ValueKey('event-grabber')),
                          ),
                        ),
                      ),
                    ),
                    ..._buttons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The gradient's stops, from the centre out: everyone who goes, in their
  /// colours (the user's own event: just the user). A single colour gets
  /// black as its second stop.
  List<Color> _colors(Invite? invite) {
    final own = OwnEventColor.of(context);
    Color colorOf(FriendInfo person) => person.id == widget.me.id
        ? own
        : avatarColorFor(id: person.id, username: person.username);
    final colors = invite == null
        ? [own]
        : [
            for (final person in _people(
              invite,
            ).going.take(EventGradient.maxColors))
              colorOf(person),
          ];
    return colors.length == 1 ? [colors.single, EventPageStyle.dark] : colors;
  }

  RsvpStatus _mine(Invite invite) =>
      _answer ?? invite.statusOf(widget.me.id) ?? RsvpStatus.pending;

  /// Everyone by answer, the user's taken from [_answer] while it travels.
  ({
    List<FriendInfo> going,
    List<FriendInfo> notGoing,
    List<FriendInfo> pending,
  })
  _people(Invite invite) {
    final me = widget.me.id;
    final mine = _mine(invite);
    // The user who said yes stands first, left of the organizer.
    final going = <FriendInfo>[invite.organizer];
    var meGoing = false;
    final notGoing = <FriendInfo>[];
    final pending = <FriendInfo>[];
    for (final participant in invite.participants) {
      final person = participant.person;
      final status = person.id == me ? mine : participant.status;
      switch (status) {
        case RsvpStatus.going:
          if (person.id == me) {
            meGoing = true;
          } else {
            going.add(person);
          }
        case RsvpStatus.notGoing:
          notGoing.add(person);
        case RsvpStatus.pending:
          // The user's own avatar waits by "Отметить присутствие".
          if (person.id != me) pending.add(person);
      }
    }
    if (meGoing) going.insert(0, widget.me);
    return (going: going, notGoing: notGoing, pending: pending);
  }

  /// The corner buttons swap with a fade and a small grow, in step with
  /// the rest of the page.
  List<Widget> _buttons() {
    const inset = EventPageStyle.buttonInset;
    Widget corner(Widget? child) => AnimatedSwitcher(
      duration: EventPageStyle.motion,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.8, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child ?? const SizedBox(key: ValueKey('none')),
    );
    return [
      Positioned(
        top: inset,
        left: inset,
        child: corner(
          _editing
              ? PillButton(
                  key: const ValueKey('event-delete'),
                  icon: CupertinoIcons.trash,
                  label: _own ? 'Удалить событие' : 'Отменить событие',
                  onPressed: _busy ? null : _delete,
                )
              : null,
        ),
      ),
      Positioned(
        top: inset,
        right: inset,
        child: corner(
          _editing
              ? PillButton(
                  key: const ValueKey('event-save'),
                  icon: CupertinoIcons.checkmark_alt,
                  label: widget.subject is NewInvite
                      ? 'Отправить приглашение'
                      : 'Сохранить',
                  onPressed: _busy ? null : _confirm,
                )
              : _canEdit
              ? PillButton(
                  key: const ValueKey('event-edit'),
                  icon: CupertinoIcons.pencil,
                  label: 'Изменить',
                  onPressed: _edit,
                )
              : null,
        ),
      ),
    ];
  }

  Widget _content(Invite? invite, MediaQueryData media) {
    final event = _event;
    final showing = _editing
        ? _span
        : invite != null
        ? EventSpan.of(
            CalendarEvent(
              id: invite.id,
              title: invite.title,
              start: invite.start,
              end: invite.end,
              allDay: invite.allDay,
            ),
          )
        : EventSpan.of(event!);
    final title = invite?.title ?? event?.title ?? '';
    final description = invite?.description.trim() ?? '';
    final repeat = _editing ? _repeat : event?.repeat;
    // A tap on empty space closes an open wheel or month; buttons, fields
    // and the pickers themselves take their own taps first.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _pickers.closeAll,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          EventPageStyle.gutter,
          EventPageStyle.button + EventPageStyle.buttonInset + 18,
          EventPageStyle.gutter,
          media.viewInsets.bottom + media.padding.bottom + 48,
        ),
        children: [
          _status(invite),
          const SizedBox(height: 10),
          // The frame is always there, clear while viewing: switching into
          // editing changes no size and moves nothing.
          AnimatedContainer(
            duration: EventPageStyle.motion,
            curve: Curves.easeOutCubic,
            padding: EventPageStyle.titleInset,
            decoration: BoxDecoration(
              border: Border.all(
                color: _editing
                    ? EventPageStyle.titleFrame
                    : EventPageStyle.titleFrame.withValues(alpha: 0),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: _editing
                ? FitTitle(
                    key: const ValueKey('event-title-field'),
                    text: '',
                    style: EventPageStyle.title,
                    controller: _title,
                    focusNode: _titleFocus,
                  )
                : FitTitle(
                    key: const ValueKey('event-title'),
                    text: title.trim().isEmpty ? 'Без названия' : title.trim(),
                    style: EventPageStyle.title,
                  ),
          ),
          if (invite != null) _Together(invite: invite, me: widget.me),
          if (!_own)
            Reveal(
              open: true,
              contentKey: _editing
                  ? 'edit'
                  : description.isEmpty
                  ? 'none'
                  : 'text',
              child: _editing
                  ? Padding(
                      key: const ValueKey('description-field'),
                      padding: const EdgeInsets.only(top: 14),
                      // A small light frame says the description can be
                      // written.
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: EventPageStyle.fieldFrame,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: TextField(
                                controller: _description,
                                minLines: 1,
                                maxLines: 4,
                                textAlign: TextAlign.center,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                cursorColor: Colors.white,
                                style: EventPageStyle.description,
                                decoration: InputDecoration(
                                  hintText: 'Описание',
                                  hintStyle: EventPageStyle.description
                                      .copyWith(color: const Color(0x80FFFFFF)),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : description.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      key: const ValueKey('description'),
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        style: EventPageStyle.description,
                      ),
                    ),
            ),
          const SizedBox(height: 32),
          WhenBlock(
            span: showing,
            editing: _editing,
            pickers: _pickers,
            onChanged: (span) => setState(() => _span = span),
          ),
          const SizedBox(height: 36),
          if (_own)
            Reveal(
              open: true,
              contentKey: _editing
                  ? 'edit'
                  : repeat == null
                  ? 'none'
                  : 'view',
              child: _editing
                  ? EventRepeatBlock(
                      key: const ValueKey('repeat-edit'),
                      rule: _repeat,
                      day: _span.firstDay,
                      decoration: EventPageStyle.block,
                      picked: Colors.white,
                      pickedInk: Colors.black,
                      pickers: _pickers,
                      onChanged: (rule) => setState(() => _repeat = rule),
                    )
                  : repeat == null
                  ? const SizedBox(width: double.infinity)
                  : RepeatSummary(rule: repeat, day: showing.firstDay),
            )
          else if (invite != null)
            _attendance(invite),
        ],
      ),
    );
  }

  Widget _status(Invite? invite) {
    final style = EventPageStyle.status;
    if (invite == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Мои события', style: style),
          const SizedBox(width: 8),
          const Icon(CupertinoIcons.calendar, color: Colors.white, size: 22),
        ],
      );
    }
    final organizer = invite.organizer;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Организатор', style: style),
        const SizedBox(width: 8),
        PersonAvatar(
          id: organizer.id,
          name: organizer.name,
          username: organizer.username,
          size: 26,
          color: organizer.id == widget.me.id
              ? OwnEventColor.of(context)
              : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _firstName(organizer),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _attendance(Invite invite) {
    final people = _people(invite);
    return AttendanceBlock(
      me: widget.me,
      own: OwnEventColor.of(context),
      mine: _organizer ? RsvpStatus.going : _mine(invite),
      organizer: _organizer,
      going: people.going,
      notGoing: people.notGoing,
      enabled: !_busy,
      onAnswer: _respond,
      onCancelEvent: _cancelInvite,
    );
  }
}

/// "Алина" from "Алина Смирнова"; the username without a name.
String _firstName(FriendInfo person) {
  final name = person.name.trim();
  return name.isEmpty ? person.username : name.split(RegExp(r'\s+')).first;
}

class _Grabber extends StatelessWidget {
  const _Grabber({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: EventPageStyle.grabber.width,
    height: EventPageStyle.grabber.height,
    decoration: BoxDecoration(
      color: EventPageStyle.grabberColor,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// "Вместе с" and everyone invited but the organizer, overlapping a
/// little; the user in their own colour.
class _Together extends StatelessWidget {
  const _Together({required this.invite, required this.me});

  final Invite invite;
  final FriendInfo me;

  static const _size = 28.0;
  static const _step = 20.0;
  static const _shown = 8;

  @override
  Widget build(BuildContext context) {
    final people = [
      for (final participant in invite.participants) participant.person,
    ];
    if (people.isEmpty) return const SizedBox.shrink();
    final own = OwnEventColor.of(context);
    final shown = people.take(_shown).toList();
    final extra = people.length - shown.length;
    return Padding(
      key: const ValueKey('together'),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Вместе с', style: EventPageStyle.caption),
          const SizedBox(width: 10),
          SizedBox(
            width: _size + (shown.length - 1) * _step,
            height: _size,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * _step,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x40000000),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: PersonAvatar(
                          id: shown[i].id,
                          name: shown[i].name,
                          username: shown[i].username,
                          size: _size - 4,
                          color: shown[i].id == me.id ? own : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (extra > 0) ...[
            const SizedBox(width: 6),
            Text('+$extra', style: EventPageStyle.caption),
          ],
        ],
      ),
    );
  }
}
