import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invites_source.dart';
import 'package:flutter/foundation.dart';

class InvitesStore extends ChangeNotifier {
  InvitesStore(this._source) {
    _source.changes?.addListener(load);
  }

  InvitesSource _source;
  List<Invite>? _invites;
  Object? _error;
  var _generation = 0;
  bool _disposed = false;

  List<Invite>? get invites => _invites;
  Object? get error => _error;

  Invite? byId(String id) {
    for (final invite in _invites ?? const <Invite>[]) {
      if (invite.id == id) return invite;
    }
    return null;
  }

  set source(InvitesSource value) {
    if (identical(value, _source)) return;
    _source.changes?.removeListener(load);
    _source.dispose();
    _source = value;
    _source.changes?.addListener(load);
    _invites = null;
    _error = null;
    notifyListeners();
    load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final invites = await _source.list();
      if (_disposed || generation != _generation) return;
      _invites = invites;
      _error = null;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error;
      _invites ??= const [];
    }
    notifyListeners();
  }

  Future<Invite> create(InviteDraft draft) async {
    final invite = await _source.create(draft);
    await load();
    return invite;
  }

  Future<void> update(String id, InviteDraft draft) async {
    await _source.update(id, draft);
    await load();
  }

  Future<void> respond(String id, RsvpStatus status) async {
    await _source.respond(id, status);
    await load();
  }

  Future<void> cancel(String id) async {
    await _source.cancel(id);
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _source.changes?.removeListener(load);
    _source.dispose();
    super.dispose();
  }
}
