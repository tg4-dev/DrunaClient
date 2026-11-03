import 'package:druna_app/shared/ui/action_pill.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the accepting ✓ is filled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActionPill(
          icon: Icons.check_rounded,
          label: 'Принять',
          filled: true,
          onPressed: () {},
        ),
      ),
    );
    final pill = tester.widget<PillButton>(find.byType(PillButton));
    expect(pill.fill, Colors.white);
    expect(pill.color, Colors.black);
  });
}
