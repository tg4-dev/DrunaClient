import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showAvatarTuning(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const AvatarTuningPage()));

class AvatarTuningPage extends StatefulWidget {
  const AvatarTuningPage({super.key});

  static const letters = [
    'А',
    'Б',
    'Д',
    'Ж',
    'Щ',
    'N',
    'а',
    'б',
    'д',
    'у',
    'g',
  ];

  @override
  State<AvatarTuningPage> createState() => _AvatarTuningPageState();
}

class _AvatarTuningPageState extends State<AvatarTuningPage> {
  var _index = 0;

  final _tuned = <String, AvatarFont>{};
  var _letter = 'А';
  var _guides = true;

  AvatarFont get _font => _tuned[avatarFonts[_index].id] ?? avatarFonts[_index];

  void _tune({double? scale, double? dx, double? dy}) => setState(() {
    _tuned[_font.id] = _font.copyWith(scale: scale, dx: dx, dy: dy);
  });

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _font.toCode()));
    if (mounted) showToast(context, 'Скопировано: ${_font.id}');
  }

  @override
  Widget build(BuildContext context) {
    final font = _font;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Подгонка аватаров'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: avatarFonts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => PillButton(
                text: avatarFonts[i].id,
                fill: i == _index ? avatarPalette[6] : PillStyle.fill,
                onPressed: () => setState(() => _index = i),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: _Circle(
              font: font,
              letter: font.cased(_letter),
              size: 200,
              guides: _guides,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final letter in AvatarTuningPage.letters)
                GestureDetector(
                  onTap: () => setState(() => _letter = letter),
                  child: _Circle(
                    font: font,
                    letter: letter,
                    size: 56,
                    guides: _guides,
                    picked: letter == _letter,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Буквы в сетке — как есть, в обоих регистрах; большой круг — в '
            'регистре шрифта.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SheetStyle.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _Slider(
            label: 'scale',
            value: font.scale,
            min: 0.3,
            max: 1.2,
            onChanged: (v) => _tune(scale: v),
          ),
          _Slider(
            label: 'dx',
            value: font.dx,
            min: -0.15,
            max: 0.15,
            onChanged: (v) => _tune(dx: v),
          ),
          _Slider(
            label: 'dy',
            value: font.dy,
            min: -0.15,
            max: 0.15,
            onChanged: (v) => _tune(dy: v),
          ),
          Row(
            children: [
              const Text(
                'Направляющие',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              const Spacer(),
              CupertinoSwitch(
                value: _guides,
                onChanged: (v) => setState(() => _guides = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              font.toCode(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Menlo',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: PillButton(
              icon: CupertinoIcons.doc_on_clipboard,
              text: 'Скопировать значения',
              onPressed: _copy,
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    required this.font,
    required this.letter,
    required this.size,
    required this.guides,
    this.picked = false,
  });

  final AvatarFont font;
  final String letter;
  final double size;
  final bool guides;
  final bool picked;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: avatarGradient(avatarPalette[0]),
      shape: BoxShape.circle,
      border: picked ? Border.all(color: Colors.white, width: 2) : null,
    ),
    child: AvatarLetter(letter: letter, font: font, size: size, guides: guides),
  );
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 52,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      Expanded(
        child: CupertinoSlider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 56,
        child: Text(
          value.toStringAsFixed(3),
          textAlign: TextAlign.right,
          style: const TextStyle(color: SheetStyle.muted, fontSize: 13),
        ),
      ),
    ],
  );
}
