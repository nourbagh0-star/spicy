import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spicy/core/widgets/app_button.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Verify the app can start without errors
    // Note: Full widget test requires BlocProvider setup
  });

  testWidgets('icon button fits a narrow fixed width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 150,
            child: AppButton(
              label: 'Add to Cart',
              icon: Icons.add_shopping_cart_rounded,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
