import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    return host;
  }

  testWidgets('drops in at the top and leaves by itself', (tester) async {
    final context = await pumpHost(tester);
    showToast(context, 'Выбор друзей сброшен');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final toast = find.text('Выбор друзей сброшен');
    expect(toast, findsOneWidget);
    expect(tester.getRect(toast).top, inInclusiveRange(8, 60));

    await tester.pump(ToastStyle.hold);
    await tester.pumpAndSettle();
    expect(toast, findsNothing);
  });

  testWidgets('a new message replaces the old; a tap sends it away', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    showToast(context, 'Первое');
    await tester.pump();
    showToast(context, 'Второе', error: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Первое'), findsNothing);
    expect(find.text('Второе'), findsOneWidget);

    await tester.tap(find.text('Второе'));
    await tester.pumpAndSettle();
    expect(find.text('Второе'), findsNothing);
  });
}
