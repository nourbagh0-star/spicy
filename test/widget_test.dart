import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/widgets/app_button.dart';
import 'package:spicy/core/widgets/filter_chip_bar.dart';
import 'package:spicy/core/widgets/responsive_content.dart';

void main() {
  testWidgets('responsive content stays centered and width constrained', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: ResponsiveContent(
              maxWidth: 600,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(key: const Key('content')),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('content'))).width, 560);
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

  testWidgets('category chips select a category without layout errors', (
    tester,
  ) async {
    final locale = AppLocale();
    String selected = 'All';

    await tester.pumpWidget(
      ChangeNotifierProvider<AppLocale>.value(
        value: locale,
        child: MaterialApp(
          home: Scaffold(
            body: FilterChipBar(
              categories: const ['All', 'ПИЦЦА'],
              selectedCategory: selected,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ПИЦЦА'));
    await tester.pumpAndSettle();

    expect(selected, 'ПИЦЦА');
    expect(tester.takeException(), isNull);
  });
}
