import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ValueNotifier<bool?>> pumpConfirm(WidgetTester tester) async {
    final result = ValueNotifier<bool?>(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.value = await confirmAction(
              context,
              title: 'Удалить встречу?',
              message: 'Это действие нельзя отменить.',
              confirmLabel: 'Удалить',
              destructive: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить встречу?'), findsOneWidget);
    return result;
  }

  testWidgets('confirmAction resolves true on confirm', (tester) async {
    final result = await pumpConfirm(tester);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(result.value, isTrue);
    expect(find.text('Удалить встречу?'), findsNothing);
  });

  testWidgets('confirmAction resolves false on cancel', (tester) async {
    final result = await pumpConfirm(tester);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(result.value, isFalse);
  });

  testWidgets('confirmAction resolves false on barrier tap', (tester) async {
    final result = await pumpConfirm(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(result.value, isFalse);
  });
}
