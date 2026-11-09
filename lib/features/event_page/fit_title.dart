import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const titleMinTrackingEm = -0.04;
const titleMinScaleX = 0.8;
const titleMinSizeShare = 0.8;

TextStyle titleStyleAt(TextStyle style, double size, double spacing) =>
    style.copyWith(
      fontSize: size,
      letterSpacing: spacing,
      wordSpacing: spacing < 0 ? -spacing * 3 : 0,
    );

const titleMaxLines = 4;

@immutable
class TitleFit {
  const TitleFit({
    required this.lines,
    required this.fontSize,
    required this.letterSpacing,
    required this.scaleX,
    required this.lineHeight,
    required this.overflows,
  });

  final List<String> lines;
  final double fontSize;
  final double letterSpacing;

  final double scaleX;
  final double lineHeight;

  final bool overflows;
}

TitleFit fitTitle(
  String text,
  TextStyle style,
  double maxWidth, {
  TextScaler textScaler = TextScaler.noScaling,
  int maxLines = titleMaxLines,
}) {
  final base = style.fontSize!;
  double width(String line, double size, double spacing) =>
      _paint(line, style, size, spacing, textScaler).width;
  double heightAt(double size) =>
      _paint('Ж', style, size, 0, textScaler).height;

  TitleFit? single(List<String> lines, String widest) {
    final loose = width(widest, base, 0);
    if (loose <= maxWidth) {
      return TitleFit(
        lines: lines,
        fontSize: base,
        letterSpacing: 0,
        scaleX: 1,
        lineHeight: heightAt(base),
        overflows: false,
      );
    }
    final tightSpacing = base * titleMinTrackingEm;
    final tight = width(widest, base, tightSpacing);
    if (tight <= maxWidth) {
      final share = (loose - maxWidth) / (loose - tight);
      return TitleFit(
        lines: lines,
        fontSize: base,
        letterSpacing: tightSpacing * share,
        scaleX: 1,
        lineHeight: heightAt(base),
        overflows: false,
      );
    }
    final squeeze = maxWidth / tight;
    if (squeeze >= titleMinScaleX) {
      return TitleFit(
        lines: lines,
        fontSize: base,
        letterSpacing: tightSpacing,
        scaleX: squeeze,
        lineHeight: heightAt(base),
        overflows: false,
      );
    }
    final share = maxWidth / (tight * titleMinScaleX);
    if (share >= titleMinSizeShare) {
      final size = base * share;
      return TitleFit(
        lines: lines,
        fontSize: size,
        letterSpacing: size * titleMinTrackingEm,
        scaleX: titleMinScaleX,
        lineHeight: heightAt(size),
        overflows: false,
      );
    }
    return null;
  }

  final trimmed = text.trim();
  final one = single([trimmed], trimmed);
  if (one != null) return one;

  final words = trimmed.split(RegExp(r'\s+'));
  final widths = {for (final word in words) word: width(word, base, 0)};
  final space = width('Ж Ж', base, 0) - 2 * width('Ж', base, 0);
  for (var count = 2; count <= maxLines && count <= words.length; count++) {
    final lines = _balanced(words, count, widths, space);
    final widest = lines.reduce(
      (a, b) => width(a, base, 0) >= width(b, base, 0) ? a : b,
    );
    final fit = single(lines, widest);
    if (fit != null) return fit;
  }
  final tight = _tightest([trimmed], base, textScaler, style);
  return TitleFit(
    lines: tight.lines,
    fontSize: tight.fontSize,
    letterSpacing: tight.letterSpacing,
    scaleX: 1,
    lineHeight: tight.lineHeight,
    overflows: true,
  );
}

List<String> _balanced(
  List<String> words,
  int count,
  Map<String, double> widths,
  double space,
) {
  double lineWidth(int from, int to) {
    var total = space * (to - from - 1);
    for (var i = from; i < to; i++) {
      total += widths[words[i]]!;
    }
    return total;
  }

  List<int>? best;
  var bestWidest = double.infinity;
  void search(int from, List<int> cuts) {
    if (cuts.length == count - 1) {
      final bounds = [0, ...cuts, words.length];
      var widest = 0.0;
      for (var i = 0; i + 1 < bounds.length; i++) {
        final w = lineWidth(bounds[i], bounds[i + 1]);
        if (w > widest) widest = w;
      }
      if (widest < bestWidest) {
        bestWidest = widest;
        best = [...cuts];
      }
      return;
    }
    final left = count - 1 - cuts.length;
    for (var cut = from + 1; cut <= words.length - left; cut++) {
      search(cut, [...cuts, cut]);
    }
  }

  search(0, const []);
  final bounds = [0, ...best!, words.length];
  return [
    for (var i = 0; i + 1 < bounds.length; i++)
      words.sublist(bounds[i], bounds[i + 1]).join(' '),
  ];
}

TitleFit _tightest(
  List<String> lines,
  double base,
  TextScaler scaler,
  TextStyle style,
) {
  final size = base * titleMinSizeShare;
  return TitleFit(
    lines: lines,
    fontSize: size,
    letterSpacing: size * titleMinTrackingEm,
    scaleX: titleMinScaleX,
    lineHeight: _paint('Ж', style, size, 0, scaler).height,
    overflows: true,
  );
}

({double width, double height}) _paint(
  String text,
  TextStyle style,
  double size,
  double spacing,
  TextScaler scaler,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: titleStyleAt(style, size, spacing)),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final measured = (width: painter.width, height: painter.height);
  painter.dispose();
  return measured;
}

class FitTitle extends StatefulWidget {
  const FitTitle({
    required this.text,
    required this.style,
    this.controller,
    this.focusNode,
    this.placeholder = 'НАЗВАНИЕ',
    this.maxLines = titleMaxLines,
    super.key,
  });

  final int maxLines;

  final String text;
  final TextStyle style;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  final String placeholder;

  static const caretRoom = 8.0;

  static bool blink = true;

  @override
  State<FitTitle> createState() => _FitTitleState();
}

class _FitTitleState extends State<FitTitle> {
  TitleFit? _fit;
  Object? _fitFor;

  TitleFit _fitted(String text, double width, TextScaler scaler) {
    final key = (text, widget.style, width, scaler, widget.maxLines);
    if (_fit == null || _fitFor != key) {
      _fit = fitTitle(
        text.toUpperCase(),
        widget.style,
        width,
        textScaler: scaler,
        maxLines: widget.maxLines,
      );
      _fitFor = key;
    }
    return _fit!;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final controller = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final room = width - FitTitle.caretRoom;
        if (controller == null) {
          return Semantics(
            header: true,
            label: widget.text,
            excludeSemantics: true,
            child: _lines(_fitted(widget.text, room, scaler), width),
          );
        }
        final focus = widget.focusNode;
        return ListenableBuilder(
          listenable: Listenable.merge([controller, ?focus]),
          builder: (context, _) {
            final empty = controller.text.trim().isEmpty;
            final fit = _fitted(
              empty ? widget.placeholder : controller.text,
              room,
              scaler,
            );
            return Stack(
              children: [
                _lines(
                  fit,
                  width,
                  faint: empty,
                  caret: focus?.hasFocus ?? false,
                  caretFirst: empty,
                ),
                Positioned.fill(child: _input()),
              ],
            );
          },
        );
      },
    );
  }

  TextStyle _style(TitleFit fit) =>
      titleStyleAt(widget.style, fit.fontSize, fit.letterSpacing);

  Widget _lines(
    TitleFit fit,
    double width, {
    bool faint = false,
    bool caret = false,
    bool caretFirst = false,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    var style = _style(fit);
    if (faint) style = style.copyWith(color: const Color(0x80FFFFFF));
    InlineSpan caretSpan() => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _Caret(height: fit.fontSize * 0.95),
    );
    Text line(String text, {bool first = false, bool last = false}) =>
        Text.rich(
          TextSpan(
            children: [
              if (caret && caretFirst && first) caretSpan(),
              TextSpan(text: text),
              if (caret && !caretFirst && last) caretSpan(),
            ],
          ),
          maxLines: fit.overflows
              ? (widget.maxLines < titleMaxLines ? widget.maxLines : null)
              : 1,
          softWrap: fit.overflows,
          textAlign: TextAlign.center,
          textScaler: scaler,
          style: style,
        );
    if (fit.overflows) {
      return line(fit.lines.join(' '), first: true, last: true);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < fit.lines.length; i++)
          _line(
            fit,
            width,
            line(fit.lines[i], first: i == 0, last: i == fit.lines.length - 1),
          ),
      ],
    );
  }

  Widget _line(TitleFit fit, double width, Widget child) => SizedBox(
    width: width,
    height: fit.lineHeight,
    child: OverflowBox(
      minWidth: 0,
      maxWidth: width / fit.scaleX,
      child: Transform.scale(scaleX: fit.scaleX, scaleY: 1, child: child),
    ),
  );

  Widget _input() {
    return Opacity(
      opacity: 0,
      child: TextField(
        key: const ValueKey('sheet-title'),
        controller: widget.controller,
        focusNode: widget.focusNode,
        expands: true,
        maxLines: null,
        showCursor: false,
        enableInteractiveSelection: false,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [FilteringTextInputFormatter.deny('\n')],
        onSubmitted: (_) => widget.focusNode?.unfocus(),
        style: const TextStyle(color: Color(0x00000000)),
        decoration: const InputDecoration(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({required this.height});

  final double height;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (FitTitle.blink) _blink.repeat();
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FadeTransition(
        opacity: _blink.drive(
          TweenSequence([
            TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
            TweenSequenceItem(tween: ConstantTween(0.0), weight: 25),
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
          ]),
        ),
        child: Container(
          width: 3,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
  }
}
