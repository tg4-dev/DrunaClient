import 'dart:async';

import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/friends/friends_source.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Measurements of the friends page. Colours and block shape come from
/// [SheetStyle], so the page reads as the same family as the event sheet.
abstract final class FriendsStyle {
  static const avatar = 48.0;
  static const button = 44.0;
  static const success = Color(0xFF34C759);
  static const searchDebounce = Duration(milliseconds: 350);

  /// A row folds away this fast after ✓, ✕ or delete.
  static const leave = Duration(milliseconds: 180);
  static const fade = Duration(milliseconds: 140);

  static const name = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  static const username = TextStyle(
    color: SheetStyle.muted,
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );
}

/// "Друзья": the page left of the month. Incoming requests with ✓ and ✕,
/// the friends list, and search by username to send a request.
class FriendsPage extends StatefulWidget {
  const FriendsPage({required this.source, this.onChanged, super.key});

  final FriendsSource source;

  /// After a friend was added or removed, so the friend bar can reload.
  final VoidCallback? onChanged;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _query = TextEditingController();

  /// The page's own messenger: every page of the home plane is mounted at
  /// once, and a shared one would show the snackbar on all of them.
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Timer? _debounce;

  List<FriendInfo>? _friends;
  List<FriendInfo> _incoming = const [];
  List<FriendInfo> _outgoing = const [];
  Object? _error;

  List<FriendInfo>? _results;
  var _searching = false;

  /// Usernames with a request in flight: their buttons are disabled.
  final _busy = <String>{};

  /// Rows playing their exit, as `section:username`.
  final _gone = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Duration get _motion => MediaQuery.of(context).disableAnimations
      ? Duration.zero
      : FriendsStyle.leave;

  /// With lists on screen a failed load keeps them and shows a snackbar;
  /// without them the page shows the error with a retry.
  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        widget.source.listFriends(),
        widget.source.incomingRequests(),
        widget.source.outgoingRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0];
        _incoming = results[1];
        _outgoing = results[2];
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (_friends != null) {
        _toast(error);
      } else {
        setState(() => _error = error);
      }
    }
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < 2) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(FriendsStyle.searchDebounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final found = await widget.source.search(query);
      if (!mounted || _query.text.trim() != query) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || _query.text.trim() != query) return;
      setState(() => _searching = false);
      _toast(error);
    }
  }

  void _clearSearch() {
    _query.clear();
    _onQueryChanged('');
  }

  /// Runs [action] for [person]. On success the row in [leaving] (if any)
  /// plays its exit, then the lists reload. Nothing changes on failure.
  Future<void> _act(
    FriendInfo person,
    Future<void> Function(String username) action, {
    String? leaving,
  }) async {
    final username = person.username;
    if (_busy.contains(username)) return;
    setState(() => _busy.add(username));
    try {
      await action(username);
      widget.onChanged?.call();
      if (!mounted) return;
      if (leaving != null) {
        setState(() => _gone.add('$leaving:$username'));
        await Future<void>.delayed(_motion);
      }
      await _load();
    } catch (error) {
      if (mounted) _toast(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(username);
          _gone.remove('$leaving:$username');
        });
      }
    }
  }

  Future<void> _remove(FriendInfo friend) async {
    final confirmed = await confirmAction(
      context,
      title: 'Удалить из друзей?',
      message: '${_displayName(friend)} пропадёт из списка друзей.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _act(friend, widget.source.remove, leaving: 'friend');
  }

  void _toast(Object error) {
    final message = error is ApiException
        ? error.message
        : 'Не получилось. Попробуй ещё раз.';
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) =>
      ScaffoldMessenger(key: _messenger, child: _page(context));

  Widget _page(BuildContext context) {
    final friends = _friends;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              PageStyle.gutter,
              8,
              PageStyle.gutter,
              40,
            ),
            children: [
              const Text('Друзья', style: PageStyle.title),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: FriendsStyle.fade,
                child: Text(
                  friends == null ? ' ' : friendsCountLabel(friends.length),
                  key: ValueKey(friends?.length),
                  style: SheetStyle.value,
                ),
              ),
              const SizedBox(height: 16),
              _SearchField(
                controller: _query,
                searching: _searching,
                onChanged: _onQueryChanged,
                onClear: _clearSearch,
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: FriendsStyle.fade,
                // Passthrough: the blocks take the full width of the list.
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.passthrough,
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: _body(friends),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(List<FriendInfo>? friends) {
    final results = _results;
    if (results != null) {
      return _SearchResults(
        key: const ValueKey('search'),
        results: results,
        isFriend: (person) =>
            friends?.any((f) => f.username == person.username) ?? false,
        isOutgoing: (person) =>
            _outgoing.any((p) => p.username == person.username),
        isIncoming: (person) =>
            _incoming.any((p) => p.username == person.username),
        busy: _busy,
        onAdd: (person) => _act(person, widget.source.sendRequest),
      );
    }
    if (_error != null && friends == null) {
      return BlockMessage(
        key: const ValueKey('error'),
        title: 'Не удалось загрузить друзей',
        body: _error is ApiException
            ? (_error as ApiException).message
            : 'Проверь соединение и попробуй ещё раз.',
        action: 'Повторить',
        onAction: _load,
      );
    }
    if (friends == null) {
      return const Padding(
        key: ValueKey('loading'),
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CupertinoActivityIndicator(radius: 12)),
      );
    }
    return Column(
      key: const ValueKey('lists'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Collapsible(
          gone: _incoming.isEmpty,
          motion: _motion,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BlockSection(
              icon: CupertinoIcons.person_badge_plus_fill,
              title: 'Заявки',
              children: [
                for (final person in _incoming)
                  _Collapsible(
                    key: ValueKey('request:${person.username}'),
                    gone: _gone.contains('request:${person.username}'),
                    motion: _motion,
                    child: _PersonRow(
                      person: person,
                      trailing: _RequestButtons(
                        name: _displayName(person),
                        enabled: !_busy.contains(person.username),
                        onAccept: () => _act(
                          person,
                          widget.source.accept,
                          leaving: 'request',
                        ),
                        onReject: () => _act(
                          person,
                          widget.source.reject,
                          leaving: 'request',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (friends.isEmpty)
          const BlockMessage(
            title: 'Здесь появятся твои друзья',
            body: 'Найди человека по нику в поиске выше и отправь заявку.',
          )
        else
          BlockSection(
            icon: CupertinoIcons.person_2_fill,
            title: 'Твои друзья',
            children: [
              for (final friend in friends)
                _Collapsible(
                  key: ValueKey('friend:${friend.username}'),
                  gone: _gone.contains('friend:${friend.username}'),
                  motion: _motion,
                  child: _PersonRow(
                    person: friend,
                    trailing: _RoundButton(
                      icon: CupertinoIcons.xmark,
                      label: 'Удалить ${_displayName(friend)} из друзей',
                      iconColor: SheetStyle.muted,
                      onPressed: _busy.contains(friend.username)
                          ? null
                          : () => _remove(friend),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

String _displayName(FriendInfo person) =>
    person.name.trim().isEmpty ? person.username : person.name.trim();

/// "1 друг", "3 друга", "11 друзей".
String friendsCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'друг'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'друга'
      : 'друзей';
  return '$count $word';
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: SheetStyle.blockDecoration,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20, right: 10),
            child: Icon(
              CupertinoIcons.search,
              color: SheetStyle.muted,
              size: 20,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              cursorColor: SheetStyle.accent,
              style: PageStyle.body,
              // The legacy app theme fills and outlines every field; the block
              // around it is the field here.
              decoration: const InputDecoration(
                hintText: 'Найти по нику',
                hintStyle: TextStyle(color: SheetStyle.muted, fontSize: 17),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: AnimatedSwitcher(
              duration: FriendsStyle.fade,
              child: searching
                  ? const CupertinoActivityIndicator(key: ValueKey('spin'))
                  : ValueListenableBuilder(
                      valueListenable: controller,
                      builder: (context, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              key: const ValueKey('clear'),
                              tooltip: 'Очистить',
                              onPressed: onClear,
                              icon: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: SheetStyle.muted,
                                size: 20,
                              ),
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.isFriend,
    required this.isOutgoing,
    required this.isIncoming,
    required this.busy,
    required this.onAdd,
    super.key,
  });

  final List<FriendInfo> results;
  final bool Function(FriendInfo) isFriend;
  final bool Function(FriendInfo) isOutgoing;
  final bool Function(FriendInfo) isIncoming;
  final Set<String> busy;
  final ValueChanged<FriendInfo> onAdd;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const BlockMessage(
        title: 'Никого не нашли',
        body: 'Поиск работает по точному нику.',
      );
    }
    return BlockSection(
      icon: CupertinoIcons.search,
      title: 'Результаты',
      children: [
        for (final person in results)
          _PersonRow(
            key: ValueKey('result:${person.username}'),
            person: person,
            trailing: isFriend(person)
                ? const _Status('Друг')
                : isOutgoing(person)
                ? const _Status('Заявка отправлена')
                : isIncoming(person)
                ? const _Status('Ждёт ответа')
                : _RoundButton(
                    icon: CupertinoIcons.plus,
                    label: 'Добавить ${_displayName(person)} в друзья',
                    color: SheetStyle.accent,
                    onPressed: busy.contains(person.username)
                        ? null
                        : () => onAdd(person),
                  ),
          ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.trailing, super.key});

  final FriendInfo person;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return _FadeIn(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            PersonAvatar(
              id: person.id,
              name: person.name,
              username: person.username,
              size: FriendsStyle.avatar,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(person),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FriendsStyle.name,
                  ),
                  if (person.username.isNotEmpty)
                    Text(
                      '@${person.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FriendsStyle.username,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _RequestButtons extends StatelessWidget {
  const _RequestButtons({
    required this.name,
    required this.enabled,
    required this.onAccept,
    required this.onReject,
  });

  final String name;
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: CupertinoIcons.xmark,
          label: 'Отклонить заявку от $name',
          color: SheetStyle.chip,
          onPressed: enabled ? onReject : null,
        ),
        const SizedBox(width: 10),
        _RoundButton(
          icon: CupertinoIcons.checkmark_alt,
          label: 'Принять заявку от $name',
          color: FriendsStyle.success,
          // Black on green: white would be about 2.2:1.
          iconColor: Colors.black,
          onPressed: enabled ? onAccept : null,
        ),
      ],
    );
  }
}

/// A 44 pt circle with an icon. Without [color] only the icon is drawn.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: FriendsStyle.fade,
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: FriendsStyle.button,
            height: FriendsStyle.button,
            decoration: color == null
                ? null
                : BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Text(text, style: SheetStyle.caption),
  );
}

/// Folds away and fades when [gone]; nothing on the page vanishes at once.
class _Collapsible extends StatelessWidget {
  const _Collapsible({
    required this.gone,
    required this.motion,
    required this.child,
    super.key,
  });

  final bool gone;
  final Duration motion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: motion == Duration.zero ? Duration.zero : FriendsStyle.fade,
      opacity: gone ? 0 : 1,
      child: AnimatedSize(
        duration: motion,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: gone ? const SizedBox(width: double.infinity) : child,
      ),
    );
  }
}

/// Fades a row in the first time it is built.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: FriendsStyle.fade,
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}
