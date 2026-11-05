import 'package:druna_app/shared/ui/motion.dart';
import 'dart:async';

import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showToast(BuildContext context, String message, {bool error = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Toast(
      message: message,
      error: error,
      onGone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
  if (error) HapticFeedback.lightImpact();
}

OverlayEntry? _current;

abstract final class ToastStyle {
  static const top = 8.0;
  static const side = 16.0;

  static const base = Color(0xF21C1C1E);
  static const icon = 18.0;
  static const danger = Color(0xFFFF3B30);
  static const text = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 600)],
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const enter = Duration(milliseconds: 260);
  static const leave = Motion.medium;
  static const hold = Duration(milliseconds: 2400);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.error,
    required this.onGone,
  });

  final String message;
  final bool error;
  final VoidCallback onGone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: ToastStyle.enter,
    reverseDuration: ToastStyle.leave,
  );
  late final _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _hold;
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    _motion.forward();
    _hold = Timer(ToastStyle.hold, _leave);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _hold?.cancel();
    await _motion.reverse();
    if (mounted) widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + ToastStyle.top;
    return Positioned(
      top: top,
      left: ToastStyle.side,
      right: ToastStyle.side,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: GestureDetector(
            onTap: _leave,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < 0) _leave();
            },
            child: AnimatedBuilder(
              animation: _curve,
              builder: (context, child) => Opacity(
                opacity: _curve.value,
                child: Transform.translate(
                  offset: Offset(0, -24 * (1 - _curve.value)),
                  child: child,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  label: widget.message,
                  excludeSemantics: true,
                  child: _capsule(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _capsule() => DecoratedBox(
    decoration: const ShapeDecoration(
      color: ToastStyle.base,
      shape: StadiumBorder(),
    ),
    child: PillSurface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PillStyle.size),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PillStyle.padding,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.error) ...[
                const Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  color: ToastStyle.danger,
                  size: ToastStyle.icon,
                ),
                const SizedBox(width: PillStyle.gap),
              ],
              Flexible(
                child: Text(
                  widget.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ToastStyle.text,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
