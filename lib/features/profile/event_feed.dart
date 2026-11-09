import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/calendar/month_calendar.dart'
    show chromeBlurSigma;
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invite_events.dart';
import 'package:druna_app/features/invites/invite_split.dart';
import 'package:druna_app/features/invites/invites_source.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/features/profile/event_chip.dart';
import 'package:druna_app/features/profile/profile_header.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/edge_blur.dart';
import 'package:druna_app/shared/ui/motion.dart';
import 'package:druna_app/shared/ui/onest.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

abstract final class FeedStyle {
  static const sectionsGap = 28.0;
  static const headingGap = 12.0;
  static const bottom = 40.0;
  static const blurTail = 24.0;
  static const shade = Color(0xD9000000);
  static const unblurredSolid = 0.5;
  static const archiveGap = 16.0;
  static const actionGap = 8.0;

  static const stickyScale = 17 / 20;
  static const stickyColor = Color(0x99FFFFFF);

  static const muted = Color(0xB3FFFFFF);
  static const archivePill = Size(58, 40);
  static const archiveArrow = 24.0;

  static final heading = onest(20, weight: FontWeight.w600, color: muted);
  static final archiveLink = onest(
    20,
    weight: FontWeight.w600,
    color: const Color(0x99FFFFFF),
  );
  static final archiveTitle = onest(28, weight: FontWeight.w600, color: muted);
  static final note = onest(
    17,
    weight: FontWeight.w400,
    color: SheetStyle.muted,
  );
}

typedef FeedHeader =
    Widget Function(BuildContext context, double offset, double archive);

class EventFeed extends StatefulWidget {
  const EventFeed({
    required this.controller,
    required this.invites,
    required this.meId,
    required this.own,
    required this.barBottom,
    required this.header,
    required this.collapseDistance,
    required this.headerLayer,
    required this.anchor,
    this.include,
    this.expanded,
    this.editing = false,
    this.onOpenInvite,
    this.onArchiveChanged,
    this.onCollapsedChanged,
    this.emptyText = 'Зажми день в календаре друзей, чтобы позвать их',
    super.key,
  });

  final ScrollController controller;
  final InvitesStore? invites;
  final int meId;
  final Color own;

  final bool Function(Invite invite)? include;

  final double barBottom;

  final double header;

  final double collapseDistance;

  final FeedHeader headerLayer;

  final Widget? expanded;
  final bool editing;

  final ValueNotifier<double> anchor;

  final ValueChanged<String>? onOpenInvite;
  final ValueChanged<bool>? onArchiveChanged;
  final ValueChanged<bool>? onCollapsedChanged;

  final String emptyText;

  @override
  State<EventFeed> createState() => _EventFeedState();
}

class _Heading {
  const _Heading(this.title, this.top);

  final String title;
  final double top;
}

class _EventFeedState extends State<EventFeed>
    with SingleTickerProviderStateMixin {
  final _offset = ValueNotifier<double>(0);
  late final _archive = AnimationController(
    vsync: this,
    duration: Motion.medium,
  );
  var _archiveOpen = false;
  var _collapsed = false;
  var _returning = false;

  bool get _away => widget.editing || _returning;

  final _contentKey = GlobalKey();
  final _waitingKey = GlobalKey();
  final _upcomingKey = GlobalKey();
  var _headings = const <_Heading>[];

  double _pageHeight = 0;
  double _headingHeight = 0;

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    widget.invites?.addListener(_onInvites);
    _archive.addListener(_onArchive);
    _measureLater();
  }

  @override
  void didUpdateWidget(covariant EventFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    if (oldWidget.invites != widget.invites) {
      oldWidget.invites?.removeListener(_onInvites);
      widget.invites?.addListener(_onInvites);
    }
    if (oldWidget.editing != widget.editing) _returning = !widget.editing;
    if (oldWidget.header != widget.header) _measureLater();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    widget.invites?.removeListener(_onInvites);
    _offset.dispose();
    _archive.dispose();
    super.dispose();
  }

  void _onInvites() {
    setState(() {});
    _measureLater();
  }

  void _onScroll() {
    _offset.value = widget.controller.offset;
    _updateAnchor();
    _updateCollapsed();
  }

  void _onArchive() {
    _updateAnchor();
    _updateCollapsed();
  }

  void _updateCollapsed() {
    final distance = widget.collapseDistance;
    final collapsed =
        _archiveOpen || (distance > 0 && _offset.value / distance >= 0.5);
    if (collapsed == _collapsed) return;
    _collapsed = collapsed;
    widget.onCollapsedChanged?.call(collapsed);
  }

  void _settle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.editing) return;
      setState(() => _returning = false);
      _measure();
    });
  }

  var _measureScheduled = false;

  void _measureLater() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    if (_away) return;
    final content = _contentKey.currentContext?.findRenderObject();
    if (content is! RenderBox || !content.attached) return;
    final headings = <_Heading>[];
    for (final (key, title) in [
      (_waitingKey, 'Ждёт ответа'),
      (_upcomingKey, 'Предстоящие'),
    ]) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: content).dy;
      headings.add(_Heading(title, top));
    }
    if (_sameHeadings(headings, _headings)) return;
    _headings = headings;
    _updateAnchor();
    setState(() {});
  }

  void _updateAnchor() {
    if (_away || _pageHeight <= 0) return;
    const pinned = ProfileHeaderStyle.row;
    final double inScroll;
    if (_headings.isEmpty) {
      inScroll = _pageHeight / 2 - widget.barBottom;
    } else {
      final top = _headings.first.top - _offset.value;
      inScroll = top < pinned ? pinned : top;
    }
    final archived = inScroll + (pinned - inScroll) * _archive.value;
    widget.anchor.value = widget.barBottom + archived;
  }

  void _openArchive() {
    setState(() => _archiveOpen = true);
    widget.onArchiveChanged?.call(true);
    _updateCollapsed();
    _archive.animateTo(
      1,
      duration: _reduce ? Duration.zero : Motion.medium,
      curve: Motion.enter,
    );
  }

  Future<void> _closeArchive() async {
    final remaining = _archive.value;
    await _archive.animateTo(
      0,
      duration: _reduce ? Duration.zero : Motion.medium * remaining,
      curve: Motion.enter,
    );
    if (!mounted) return;
    setState(() => _archiveOpen = false);
    widget.onArchiveChanged?.call(false);
    _updateCollapsed();
  }

  void _dragArchive(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    _archive.value = (_archive.value - (details.primaryDelta ?? 0) / width)
        .clamp(0.0, 1.0);
  }

  void _releaseArchive(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 700 || (velocity > -700 && _archive.value < 0.5)) {
      _closeArchive();
    } else {
      _archive.animateTo(
        1,
        duration: Motion.medium * (1 - _archive.value),
        curve: Motion.enter,
      );
    }
  }

  double _textHeight(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double get _blurEnd =>
      widget.barBottom +
      ProfileHeaderStyle.row +
      _headingHeight +
      FeedStyle.blurTail;

  List<Invite> _mine() {
    final include = widget.include;
    return [
      for (final invite in widget.invites?.invites ?? const <Invite>[])
        if (include == null || include(invite)) invite,
    ];
  }

  InviteSplit _split() =>
      splitInvites(_mine(), meId: widget.meId, now: DateTime.now());

  @override
  Widget build(BuildContext context) {
    _headingHeight = _textHeight('Ж', FeedStyle.heading);
    return LayoutBuilder(
      builder: (context, constraints) {
        _pageHeight = constraints.maxHeight;
        final width = constraints.maxWidth;
        final list = ClipRect(
          clipper: _TopClip(
            widget.editing ? widget.barBottom + widget.header : 0,
          ),
          child: RepaintBoundary(
            child: EdgeBlur(
              sigma: chromeBlurSigma,
              gradient: _blurMask(constraints.maxHeight, _blurEnd),
              child: _scrollView(),
            ),
          ),
        );
        final archive = _archiveOpen ? _archiveLayer(width) : null;
        final distance = widget.collapseDistance;
        return AnimatedBuilder(
          animation: Listenable.merge([_offset, _archive]),
          child: list,
          builder: (context, list) {
            final t = _archive.value;
            final offset = widget.editing ? 0.0 : _offset.value;
            final shifted = offset < distance ? distance : offset;
            final effective = offset + (shifted - offset) * t;
            final collapse = distance <= 0
                ? 1.0
                : (effective / distance).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(-width * t, 0),
                    child: list,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _blurEnd,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            FeedStyle.shade.withValues(
                              alpha: FeedStyle.shade.a * collapse,
                            ),
                            if (!EdgeBlur.enabled)
                              FeedStyle.shade.withValues(
                                alpha: FeedStyle.shade.a * collapse,
                              ),
                            FeedStyle.shade.withValues(alpha: 0),
                          ],
                          stops: EdgeBlur.enabled
                              ? null
                              : const [0, FeedStyle.unblurredSolid, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: widget.barBottom,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Stack(
                    children: [
                      if (!_away)
                        Positioned.fill(
                          top: ProfileHeaderStyle.row,
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(
                                -width * t,
                                -ProfileHeaderStyle.row,
                              ),
                              child: Stack(children: _headingLabels(offset)),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: widget.headerLayer(context, effective, t),
                      ),
                      if (archive != null)
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(width * (1 - t), 0),
                            child: archive,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  LinearGradientBlur _blurMask(double height, double end) {
    final stop = height <= 0 ? 0.0 : (end / height).clamp(0.0, 1.0);
    return LinearGradientBlur(
      values: const [1, 0, 0],
      stops: [0, stop, 1],
      start: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  Widget _scrollView() {
    return SingleChildScrollView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(top: widget.barBottom, bottom: FeedStyle.bottom),
      child: _OnLayout(
        onLayout: _measureLater,
        child: Column(
          key: _contentKey,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: widget.header),
              duration: _reduce ? Duration.zero : Motion.long,
              curve: Motion.settle,
              builder: (context, height, _) =>
                  SizedBox(width: double.infinity, height: height),
            ),
            Reveal(
              open: widget.editing && widget.expanded != null,
              duration: Motion.long,
              fade: Motion.long,
              child: widget.expanded ?? const SizedBox.shrink(),
            ),
            _Leaving(
              away: widget.editing,
              distance: _pageHeight,
              onBack: _settle,
              child: RepaintBoundary(child: _events()),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _headingLabels(double offset) {
    final height = _headingHeight;
    return [
      for (var i = 0; i < _headings.length; i++)
        () {
          final heading = _headings[i];
          final next = i + 1 < _headings.length ? _headings[i + 1] : null;
          final top = stickyLabelTop(
            headingTop: heading.top - offset,
            nextHeadingTop: next == null ? null : next.top - offset,
            labelHeight: height,
          );
          final stuck = stickyProgress(heading.top - offset);
          return Positioned(
            top: top,
            left: 0,
            right: 0,
            height: height,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Center(
                  child: Transform.scale(
                    scale: 1 + (FeedStyle.stickyScale - 1) * stuck,
                    child: Text(
                      heading.title,
                      key: ValueKey('profile-label-$i'),
                      style: FeedStyle.heading.copyWith(
                        color: Color.lerp(
                          FeedStyle.heading.color,
                          FeedStyle.stickyColor,
                          stuck,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }(),
    ];
  }

  Widget _events() {
    final store = widget.invites;
    if (store == null) return const SizedBox(width: double.infinity);
    final invites = store.invites;
    final error = store.error;
    final children = <Widget>[];
    if (invites == null) {
      children.add(const Center(child: CupertinoActivityIndicator()));
    } else if (error != null && invites.isEmpty) {
      children.add(
        _Note(
          text: error is ApiException
              ? error.message
              : 'Не удалось загрузить события',
          action: error is InvitesUnavailable ? null : 'Повторить',
          onAction: store.load,
        ),
      );
    } else {
      final split = _split();
      if (split.waiting.isEmpty && split.upcoming.isEmpty) {
        children.add(_Note(text: widget.emptyText));
      }
      void section(
        Key key,
        String title,
        List<Invite> list, {
        bool pending = false,
      }) {
        if (list.isEmpty) return;
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: FeedStyle.sectionsGap));
        }
        children
          ..add(
            Center(
              child: Text(
                title,
                key: key,
                style: _away
                    ? FeedStyle.heading
                    : FeedStyle.heading.copyWith(
                        color: const Color(0x00FFFFFF),
                      ),
              ),
            ),
          )
          ..add(const SizedBox(height: FeedStyle.headingGap));
        for (var i = 0; i < list.length; i++) {
          if (i > 0) children.add(const SizedBox(height: EventChipStyle.gap));
          children.add(_chip(list[i], pending: pending));
        }
      }

      section(_waitingKey, 'Ждёт ответа', split.waiting, pending: true);
      section(_upcomingKey, 'Предстоящие', split.upcoming);
      children
        ..add(const SizedBox(height: FeedStyle.sectionsGap))
        ..add(Center(child: _ArchiveLink(onTap: _openArchive)));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PageStyle.gutter,
        FeedStyle.sectionsGap,
        PageStyle.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _chip(Invite invite, {bool pending = false, bool dimmed = false}) {
    return EventChip(
      key: ValueKey(
        dimmed ? 'archive-chip-${invite.id}' : 'profile-chip-${invite.id}',
      ),
      title: invite.title,
      start: invite.start,
      end: invite.end,
      allDay: invite.allDay,
      people: invite.people,
      colors: inviteColors(invite, meId: widget.meId, own: widget.own),
      pending: pending,
      dimmed: dimmed,
      onTap: () => widget.onOpenInvite?.call(invite.id),
    );
  }

  Widget _archiveLayer(double width) {
    final past = _split().past;
    const top = ProfileHeaderStyle.row;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) => _dragArchive(details, width),
      onHorizontalDragEnd: _releaseArchive,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: ArrowPillStyle.height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BackArrowPill(
                  key: const ValueKey('archive-back'),
                  label: 'Назад к событиям',
                  width: FeedStyle.archivePill.width,
                  height: FeedStyle.archivePill.height,
                  iconSize: FeedStyle.archiveArrow,
                  onPressed: _closeArchive,
                ),
                const SizedBox(width: FeedStyle.archiveGap),
                Text('Архив', style: FeedStyle.archiveTitle),
              ],
            ),
          ),
          Positioned(
            top: top + ArrowPillStyle.height + FeedStyle.archiveGap,
            left: 0,
            right: 0,
            bottom: 0,
            child: past.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: FeedStyle.sectionsGap),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _Note(text: 'Здесь появятся прошедшие события'),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      PageStyle.gutter,
                      FeedStyle.headingGap,
                      PageStyle.gutter,
                      FeedStyle.bottom,
                    ),
                    itemCount: past.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: EventChipStyle.gap),
                    itemBuilder: (context, index) =>
                        _chip(past[index], dimmed: true),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveLink extends StatelessWidget {
  const _ArchiveLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Архив',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('profile-archive'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: PillStyle.size,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Архив', style: FeedStyle.archiveLink),
              const SizedBox(width: FeedStyle.actionGap),
              ArrowIcon(
                color: FeedStyle.archiveLink.color!,
                size: PillStyle.icon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Leaving extends StatelessWidget {
  const _Leaving({
    required this.away,
    required this.distance,
    required this.child,
    this.onBack,
  });

  final bool away;
  final double distance;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      ignoring: away,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: away ? 1 : 0),
        duration: reduce ? Duration.zero : Motion.long,
        curve: away ? Motion.exit : Motion.enter,
        onEnd: away ? null : onBack,
        child: child,
        builder: (context, t, child) => t >= 1
            ? const SizedBox(width: double.infinity)
            : Transform.translate(
                offset: Offset(0, distance * t),
                child: child,
              ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(text, textAlign: TextAlign.center, style: FeedStyle.note),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: PillButton(text: action, onPressed: onAction),
          ),
      ],
    );
  }
}

class _TopClip extends CustomClipper<Rect> {
  const _TopClip(this.top);

  final double top;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, top.clamp(0, size.height), size.width, size.height);

  @override
  bool shouldReclip(covariant _TopClip old) => old.top != top;
}

bool _sameHeadings(List<_Heading> a, List<_Heading> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].title != b[i].title || a[i].top != b[i].top) return false;
  }
  return true;
}

class _OnLayout extends SingleChildRenderObjectWidget {
  const _OnLayout({required this.onLayout, super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOnLayout(onLayout);

  @override
  void updateRenderObject(BuildContext context, _RenderOnLayout renderObject) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderOnLayout extends RenderProxyBox {
  _RenderOnLayout(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}
