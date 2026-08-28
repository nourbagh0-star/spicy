import 'package:flutter_test/flutter_test.dart';
import 'package:spicy/core/locale/app_locale.dart';

void main() {
  group('AppLocale', () {
    test('supports Russian, English, and Arabic', () async {
      final locale = AppLocale();

      expect(locale.languageCode, 'ru');
      expect(locale.menuTitle, 'Меню');

      await locale.selectLanguage('en');
      expect(locale.languageCode, 'en');
      expect(locale.menuTitle, 'Menu');
      expect(locale.orderNumber(7), 'Order #7');
      expect(locale.orderStatus('delivered'), 'Completed');
      expect(locale.pickupAsSoonAsReady, 'Pickup: as soon as it is ready');
      expect(locale.cashOnPickup, 'Cash payment on pickup');
      expect(locale.reviewDate(DateTime.now()), 'Today');

      await locale.selectLanguage('ar');
      expect(locale.languageCode, 'ar');
      expect(locale.menuTitle, 'القائمة');
      expect(locale.allCategories, 'الكل');
      expect(locale.orderStatus('preparing'), 'قيد التحضير');
      expect(locale.sandwichType('chicken'), 'دجاج');
      expect(locale.sandwichType('lamb'), 'لحم ضأن');
    });

    test('falls back to Russian for an unsupported language', () async {
      final locale = AppLocale();

      await locale.selectLanguage('de');

      expect(locale.languageCode, 'ru');
    });
  });
}
