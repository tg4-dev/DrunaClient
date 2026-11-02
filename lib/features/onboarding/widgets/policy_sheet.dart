import 'package:druna_app/features/event_page/event_style.dart';
import 'package:flutter/material.dart';

/// The privacy policy: a dark card from the bottom, like the event page's
/// (design-system §9.9). The text is a placeholder.
Future<void> showPolicySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: EventPageStyle.dark,
      barrierColor: EventPageStyle.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EventPageStyle.radius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: false,
      builder: (context) => const _PolicySheet(),
    );

class _PolicySheet extends StatelessWidget {
  const _PolicySheet();

  static const _placeholder = [
    'Здесь будет политика конфиденциальности Druna. Текст готовится.',
    'Druna хранит имя, ник и почту, чтобы друзья могли тебя найти, и твои '
        'события, чтобы искать общее свободное время. Мы не продаём данные '
        'и не показываем рекламу.',
    'Друзья видят только занятость в те часы, которые ты им открываешь. '
        'Аккаунт и все данные можно удалить в любой момент.',
    'Вопросы о данных — на почту поддержки, она появится здесь вместе с '
        'полным текстом.',
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          EventPageStyle.gutter,
          EventPageStyle.top,
          EventPageStyle.gutter,
          24 + bottom,
        ),
        children: [
          Center(
            child: Container(
              width: EventPageStyle.grabber.width,
              height: EventPageStyle.grabber.height,
              decoration: BoxDecoration(
                color: EventPageStyle.grabberColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Политика конфиденциальности',
            style: onest(28, weight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 16),
          for (final paragraph in _placeholder) ...[
            Text(
              paragraph,
              style: onest(
                17,
                weight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
