import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLocale extends ChangeNotifier {
  final SupabaseClient? client;
  Locale _locale = const Locale('ru');

  AppLocale({this.client});

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isRussian => _locale.languageCode == 'ru';
  bool get isEnglish => _locale.languageCode == 'en';
  bool get isArabic => _locale.languageCode == 'ar';

  static const supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
    Locale('ar'),
  ];

  String get languageName {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      default:
        return 'Русский';
    }
  }

  String _translated(String ru, String en, String ar) {
    if (isArabic) return ar;
    return isEnglish ? en : ru;
  }

  /// Use for a small number of role-specific labels that do not belong in the
  /// customer-facing string catalogue. Keep all three values together so a
  /// new dashboard label cannot accidentally be Russian-only.
  String text({required String ru, required String en, required String ar}) =>
      _translated(ru, en, ar);

  void setLocale(Locale locale) {
    final code = _normalizedCode(locale.languageCode);
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> selectLanguage(String languageCode) async {
    final code = _normalizedCode(languageCode);
    setLocale(Locale(code));

    final configuredClient = client;
    final userId = configuredClient?.auth.currentUser?.id;
    if (configuredClient == null || userId == null) return;

    await configuredClient
        .from('profiles')
        .update({'preferred_locale': code})
        .eq('id', userId);
  }

  Future<void> loadSavedLocale() async {
    final configuredClient = client;
    final userId = configuredClient?.auth.currentUser?.id;
    if (configuredClient == null || userId == null) return;

    final profile = await configuredClient
        .from('profiles')
        .select('preferred_locale')
        .eq('id', userId)
        .maybeSingle();
    final savedCode = profile?['preferred_locale'] as String?;
    if (savedCode != null) setLocale(Locale(savedCode));
  }

  String _normalizedCode(String code) {
    return const {'ru', 'en', 'ar'}.contains(code) ? code : 'ru';
  }

  // ── App-wide UI strings ──
  String get appName => isRussian ? 'SPICY' : 'SPICY';
  String get tagline => _translated(
    'Вкус, который вдохновляет',
    'Taste that inspires',
    'مذاق يلهمك',
  );
  String get allCategories => _translated('Все', 'All', 'الكل');
  String get menuTitle => _translated('Меню', 'Menu', 'القائمة');
  String get searchMenu =>
      _translated('Поиск по меню', 'Search the menu', 'البحث في القائمة');
  String get noSearchResults => _translated(
    'Ничего не найдено',
    'No matching items found',
    'لم يتم العثور على نتائج',
  );
  String get discoverSubtitle => _translated(
    'Откройте наш изысканный\nвыбор блюд',
    'Discover our exquisite\nselection of flavors',
    'اكتشف تشكيلتنا المميزة\nمن النكهات',
  );
  String get orders => _translated('Заказы', 'Orders', 'الطلبات');
  String get reviews => _translated('Отзывы', 'Reviews', 'التقييمات');
  String get profile => _translated('Профиль', 'Profile', 'الحساب');
  String get cart => _translated('Корзина', 'Cart', 'السلة');
  String get addToCart =>
      _translated('В корзину', 'Add to Cart', 'أضف إلى السلة');
  String get viewCart => _translated('Корзина', 'View Cart', 'عرض السلة');
  String get checkout =>
      _translated('Оформить заказ', 'Checkout', 'إتمام الطلب');
  String get proceedToCheckout => _translated(
    'Перейти к оформлению',
    'Proceed to Checkout',
    'المتابعة لإتمام الطلب',
  );
  String get placeOrder =>
      _translated('Подтвердить заказ', 'Place Order', 'تأكيد الطلب');
  String get deliveryAddress =>
      _translated('Адрес доставки', 'Delivery Address', 'عنوان التوصيل');
  String get orderNotes =>
      _translated('Примечание к заказу', 'Order Notes', 'ملاحظات الطلب');
  String get orderSummary =>
      _translated('Итого по заказу', 'Order Summary', 'ملخص الطلب');
  String get subtotal => _translated('Подитог', 'Subtotal', 'المجموع الفرعي');
  String get delivery => _translated('Доставка', 'Delivery', 'التوصيل');
  String get free => _translated('Бесплатно', 'Free', 'مجاني');
  String get deliveryCalculatedAtCheckout => _translated(
    'Рассчитаем при оформлении',
    'Calculated at checkout',
    'تُحسب عند إتمام الطلب',
  );
  String get total => _translated('Итого', 'Total', 'الإجمالي');
  String get emptyCart =>
      _translated('Ваша корзина пуста', 'Your cart is empty', 'سلتك فارغة');
  String get emptyCartSub => _translated(
    'Загляните в наше меню',
    'Explore our menu and add something delicious',
    'استكشف قائمتنا وأضف شيئاً لذيذاً',
  );
  String get browseMenu =>
      _translated('Перейти в меню', 'Browse Menu', 'عرض القائمة');
  String get backToTop =>
      _translated('Наверх', 'Back to top', 'العودة إلى الأعلى');
  String get orderTracking =>
      _translated('Отслеживание заказа', 'Order Tracking', 'تتبع الطلب');
  String get orderTitle => _translated('Заказ', 'Order', 'الطلب');
  String get myOrders => _translated('Мои заказы', 'My Orders', 'طلباتي');
  String get noOrders =>
      _translated('Заказов пока нет', 'No orders yet', 'لا توجد طلبات بعد');
  String get trackOrder =>
      _translated('Отследить заказ →', 'Track Order →', 'تتبع الطلب ←');
  String get details => _translated('Подробнее →', 'Details →', 'التفاصيل ←');
  String get estimatedDelivery => _translated(
    'Ориентировочная доставка',
    'Estimated delivery',
    'وقت التوصيل المتوقع',
  );
  String get noReviews =>
      _translated('Отзывов пока нет', 'No reviews yet', 'لا توجد تقييمات بعد');
  String get leaveReview =>
      _translated('Оставить отзыв', 'Leave a Review', 'إضافة تقييم');
  String get reviewBranch =>
      _translated('Оценить филиал', 'Review branch', 'قيّم الفرع');
  String get rateItems =>
      _translated('Оценить блюда', 'Rate items', 'قيّم الأصناف');
  String get rateItemsTitle =>
      _translated('Оцените блюда', 'Rate your items', 'قيّم أصنافك');
  String get rateItemsSubtitle => _translated(
    'Вы можете оценить каждое блюдо из этого заказа.',
    'You can rate each item from this order.',
    'يمكنك تقييم كل صنف من هذا الطلب.',
  );
  String get itemRatingsSubmitted => _translated(
    'Спасибо за оценки блюд!',
    'Thank you for rating the items!',
    'شكراً لتقييم الأصناف!',
  );
  String get noItemsToRate => _translated(
    'Все блюда из этого заказа уже оценены.',
    'All items from this order have already been rated.',
    'تم تقييم كل أصناف هذا الطلب بالفعل.',
  );
  String get selectAtLeastOneItemRating => _translated(
    'Выберите оценку хотя бы для одного блюда.',
    'Choose a rating for at least one item.',
    'اختر تقييماً لصنف واحد على الأقل.',
  );
  String get branchRating =>
      _translated('Оценка филиала', 'Branch rating', 'تقييم الفرع');
  String ratingsCount(int count) =>
      _translated('$count оценок', '$count ratings', '$count تقييمات');
  String get noRatingsYet =>
      _translated('Пока нет оценок', 'No ratings yet', 'لا توجد تقييمات بعد');
  String get submitReview =>
      _translated('Отправить отзыв', 'Submit Review', 'إرسال التقييم');
  String get whatDidYouOrder =>
      _translated('Что вы заказали?', 'What did you order?', 'ماذا طلبت؟');
  String get selectDish =>
      _translated('Выберите блюдо', 'Select a dish', 'اختر طبقاً');
  String get yourRating => _translated('Ваша оценка', 'Your Rating', 'تقييمك');
  String get yourName => _translated('Ваше имя', 'Your Name', 'اسمك');
  String get yourReview => _translated('Ваш отзыв', 'Your Review', 'تقييمك');
  String get tellUs => _translated(
    'Расскажите о своём опыте...',
    'Tell us about your experience...',
    'أخبرنا عن تجربتك...',
  );
  String get reviewSubmitted => _translated(
    'Спасибо за ваш отзыв!',
    'Thank you for your review!',
    'شكراً لتقييمك!',
  );
  String get howWasOrder =>
      _translated('Как вам заказ?', 'How was your order?', 'كيف كان طلبك؟');
  String get reviewHelps => _translated(
    'Ваш отзыв поможет нам стать лучше.',
    'Your review helps us improve.',
    'تقييمك يساعدنا على التحسن.',
  );
  String get customerReviews =>
      _translated('Отзывы клиентов', 'Customer reviews', 'تقييمات العملاء');
  String get spicyGuest =>
      _translated('Гость Spicy', 'Spicy Guest', 'ضيف Spicy');
  String get errorLabel => _translated('Ошибка', 'Error', 'خطأ');
  String get deliveryAddressHint =>
      isRussian ? 'Введите адрес доставки' : 'Enter your delivery address';
  String get specialInstructions =>
      isRussian ? 'Особые пожелания?' : 'Any special instructions?';
  String get language => _translated('Язык', 'Language', 'اللغة');
  String get logout => _translated('Выйти', 'Log out', 'تسجيل الخروج');
  String get orderHistory =>
      _translated('История заказов', 'Order History', 'سجل الطلبات');
  String get viewPastOrders => _translated(
    'Смотреть прошлые заказы',
    'View past orders',
    'عرض الطلبات السابقة',
  );
  String get myReviews => _translated('Мои отзывы', 'My Reviews', 'تقييماتي');
  String get manageReviews => _translated(
    'Управление отзывами',
    'Manage your reviews',
    'إدارة تقييماتك',
  );
  String get phone => _translated('Телефон', 'Phone', 'الهاتف');
  String get welcomeBack =>
      _translated('С возвращением!', 'Welcome back!', 'مرحباً بعودتك!');
  String get loginSubtitle => _translated(
    'Войдите в свой аккаунт, чтобы продолжить',
    'Sign in to your account to continue',
    'سجّل الدخول إلى حسابك للمتابعة',
  );
  String get login => _translated('Войти', 'Sign In', 'تسجيل الدخول');
  String get createAccount =>
      _translated('Создать аккаунт', 'Create Account', 'إنشاء حساب');
  String get continueAsGuest =>
      _translated('Продолжить как гость', 'Continue as guest', 'المتابعة كضيف');
  String get register =>
      _translated('Зарегистрироваться', 'Sign Up', 'إنشاء حساب');
  String get registerSubtitle => _translated(
    'Присоединяйтесь к Spicy для лучшего опыта',
    'Join Spicy for the best experience',
    'انضم إلى Spicy لتجربة أفضل',
  );
  String get email => 'Email';
  String get password => _translated('Пароль', 'Password', 'كلمة المرور');
  String get confirmPassword => _translated(
    'Подтвердите пароль',
    'Confirm Password',
    'تأكيد كلمة المرور',
  );
  String get forgotPassword =>
      _translated('Забыли пароль?', 'Forgot password?', 'نسيت كلمة المرور؟');
  String get enterEmailForReset => _translated(
    'Введите email, чтобы восстановить пароль.',
    'Enter your email to reset your password.',
    'أدخل بريدك الإلكتروني لإعادة تعيين كلمة المرور.',
  );
  String get passwordResetSent => _translated(
    'Ссылка для восстановления отправлена на ваш email.',
    'A password reset link was sent to your email.',
    'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.',
  );
  String get noAccount => _translated(
    'Нет аккаунта? ',
    "Don't have an account? ",
    'ليس لديك حساب؟ ',
  );
  String get hasAccount => _translated(
    'Уже есть аккаунт? ',
    'Already have an account? ',
    'لديك حساب بالفعل؟ ',
  );
  String get or => _translated('или', 'or', 'أو');
  String get continueWithGoogle =>
      isRussian ? 'Продолжить с Google' : 'Continue with Google';
  String get continueWithApple =>
      isRussian ? 'Продолжить с Apple' : 'Continue with Apple';
  String get name => _translated('Имя', 'Name', 'الاسم');
  String get enterName =>
      _translated('Введите ваше имя', 'Enter your name', 'أدخل اسمك');
  String get enterEmail =>
      _translated('Введите email', 'Enter email', 'أدخل البريد الإلكتروني');
  String get enterPassword =>
      _translated('Введите пароль', 'Enter password', 'أدخل كلمة المرور');
  String get invalidEmail => _translated(
    'Введите корректный email',
    'Enter a valid email',
    'أدخل بريداً إلكترونياً صحيحاً',
  );
  String get minChars => _translated(
    'Минимум 6 символов',
    'Minimum 6 characters',
    '6 أحرف على الأقل',
  );
  String get passwordsNoMatch => _translated(
    'Пароли не совпадают',
    'Passwords do not match',
    'كلمتا المرور غير متطابقتين',
  );
  String get agreeTerms => isRussian
      ? 'Я согласен с условиями использования и политикой конфиденциальности'
      : 'I agree to the Terms of Service and Privacy Policy';
  String get ingredients => _translated('Состав', 'Ingredients', 'المكونات');
  String get prepTime => _translated('мин', 'min', 'دقيقة');
  String get currency => isRussian ? '₽' : '₽';

  // ── Order status labels ──
  String orderStatus(String status) {
    final map = isArabic
        ? {
            'placed': 'تم تقديم الطلب',
            'confirmed': 'تم التأكيد',
            'preparing': 'قيد التحضير',
            'readyForPickup': 'جاهز للاستلام',
            'onTheWay': 'في الطريق',
            'delivered': 'مكتمل',
            'cancelled': 'ملغي',
          }
        : isRussian
        ? {
            'placed': 'Новый',
            'confirmed': 'Принят',
            'preparing': 'Готовится',
            'readyForPickup': 'Готов',
            'onTheWay': 'В пути',
            'delivered': 'Завершён',
            'cancelled': 'Отменён',
          }
        : {
            'placed': 'New',
            'confirmed': 'Accepted',
            'preparing': 'Preparing',
            'readyForPickup': 'Ready for Pickup',
            'onTheWay': 'On the Way',
            'delivered': 'Completed',
            'cancelled': 'Cancelled',
          };
    return map[status] ?? status;
  }

  String databaseOrderStatus(String status) {
    final appStatus = switch (status) {
      'pending' => 'placed',
      'accepted' => 'confirmed',
      'preparing' => 'preparing',
      'ready_for_pickup' => 'readyForPickup',
      'out_for_delivery' => 'onTheWay',
      'completed' => 'delivered',
      'cancelled' || 'rejected' => 'cancelled',
      _ => status,
    };
    return orderStatus(appStatus);
  }

  String ratingOutOfFive(int rating) =>
      _translated('$rating из 5', '$rating out of 5', '$rating من 5');

  String orderNumber(Object number) =>
      _translated('Заказ №$number', 'Order #$number', 'الطلب رقم $number');

  String moreItems(int count) =>
      _translated('+ $count ещё', '+ $count more', '+ $count إضافي');

  String get pickupAsSoonAsReady => _translated(
    'Получение: как только будет готов',
    'Pickup: as soon as it is ready',
    'الاستلام: بمجرد أن يصبح جاهزاً',
  );

  String pickupAt(String value) =>
      _translated('Получение: $value', 'Pickup: $value', 'الاستلام: $value');

  String get deliveryAsSoonAsReady => _translated(
    'Доставка: как только будет готов',
    'Delivery: as soon as it is ready',
    'التوصيل: بمجرد أن يصبح جاهزاً',
  );

  String deliveryAt(String value) =>
      _translated('Доставка: $value', 'Delivery: $value', 'التوصيل: $value');

  String get cashOnPickup => _translated(
    'Оплата наличными при получении',
    'Cash payment on pickup',
    'الدفع نقداً عند الاستلام',
  );

  String get cashOnDelivery => _translated(
    'Оплата наличными при доставке',
    'Cash payment on delivery',
    'الدفع نقداً عند التوصيل',
  );

  String get repeatOrder =>
      _translated('Повторить заказ', 'Repeat Order', 'إعادة الطلب');
  String get returnToMenu =>
      _translated('Вернуться в меню', 'Return to Menu', 'العودة إلى القائمة');
  String get repeatOrderQuestion =>
      _translated('Повторить заказ?', 'Repeat this order?', 'إعادة هذا الطلب؟');
  String get cancel => _translated('Отмена', 'Cancel', 'إلغاء');
  String get continueLabel => _translated('Продолжить', 'Continue', 'متابعة');

  String repeatOrderExplanation(String branchName) => _translated(
    'Корзина будет заменена. Мы проверим актуальные цены и наличие в филиале $branchName.',
    'Your cart will be replaced. We will check current prices and availability at $branchName.',
    'سيتم استبدال سلتك. سنتحقق من الأسعار والتوفر الحالي في $branchName.',
  );

  String get orderBranchMissing => _translated(
    'Не удалось определить филиал этого заказа.',
    'We could not identify the branch for this order.',
    'تعذر تحديد فرع هذا الطلب.',
  );
  String get chooseBranchFirst => _translated(
    'Сначала выберите филиал в меню.',
    'Choose a branch from the menu first.',
    'اختر فرعاً من القائمة أولاً.',
  );
  String get branchUnavailable => _translated(
    'Этот филиал больше недоступен.',
    'This branch is no longer available.',
    'هذا الفرع لم يعد متاحاً.',
  );
  String get previousOrderUnavailable => _translated(
    'Ни одно блюдо из прошлого заказа сейчас недоступно.',
    'None of the items from the previous order are currently available.',
    'لا يتوفر حالياً أي عنصر من الطلب السابق.',
  );
  String get repeatOrderFailed => _translated(
    'Не удалось повторить заказ. Проверьте подключение и попробуйте снова.',
    'Could not repeat the order. Check your connection and try again.',
    'تعذرت إعادة الطلب. تحقق من اتصالك وحاول مرة أخرى.',
  );

  String repeatedItems(int added, List<String> skipped) {
    if (skipped.isEmpty) {
      return _translated(
        '$added поз. добавлено в корзину.',
        '$added items added to your cart.',
        'تمت إضافة $added عناصر إلى سلتك.',
      );
    }
    final unavailable = skipped.join(', ');
    return _translated(
      '$added поз. добавлено. Нет в наличии: $unavailable.',
      '$added items added. Unavailable: $unavailable.',
      'تمت إضافة $added عناصر. غير متوفر: $unavailable.',
    );
  }

  String translateOrderVariant(String value) {
    const english = {
      'Стандартный': 'Standard',
      'Средний': 'Medium',
      'Большой': 'Large',
    };
    const arabic = {
      'Стандартный': 'قياسي',
      'Средний': 'متوسط',
      'Большой': 'كبير',
    };
    if (isArabic) return arabic[value] ?? value;
    if (isEnglish) return english[value] ?? value;
    return value;
  }

  String reviewCount(int count) {
    if (isArabic) return '$count تقييم';
    if (isEnglish) return count == 1 ? '1 review' : '$count reviews';
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return '$count отзывов';
    if (mod10 == 1) return '$count отзыв';
    if (mod10 >= 2 && mod10 <= 4) return '$count отзыва';
    return '$count отзывов';
  }

  String reviewDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return _translated('Сегодня', 'Today', 'اليوم');
    if (diff.inDays == 1) return _translated('Вчера', 'Yesterday', 'أمس');
    if (diff.inDays < 7) {
      return _translated(
        '${diff.inDays} дн. назад',
        '${diff.inDays} days ago',
        'منذ ${diff.inDays} أيام',
      );
    }
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String items(int count) {
    if (isRussian) {
      if (count == 1) return '$count товар';
      if (count >= 2 && count <= 4) return '$count товара';
      return '$count товаров';
    }
    return count == 1 ? '$count item' : '$count items';
  }

  String addedToCart(String name) => _translated(
    '$name добавлен в корзину',
    '$name added to cart',
    'تمت إضافة $name إلى السلة',
  );

  String get retry => _translated('Повторить', 'Try Again', 'إعادة المحاولة');
  String get somethingWentWrong =>
      _translated('Что-то пошло не так', 'Something went wrong', 'حدث خطأ ما');
  String get networkError => _translated(
    'Нет подключения к интернету. Проверьте сеть и повторите попытку.',
    'No internet connection. Check your network and try again.',
    'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.',
  );
  String get timeoutError => _translated(
    'Сервер отвечает слишком долго. Повторите попытку.',
    'The server is taking too long to respond. Please try again.',
    'استغرق الخادم وقتاً طويلاً للاستجابة. حاول مرة أخرى.',
  );
  String get invalidCredentials => _translated(
    'Неверный email или пароль.',
    'Incorrect email or password.',
    'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
  );
  String get emailNotConfirmed => _translated(
    'Сначала подтвердите email.',
    'Please confirm your email first.',
    'يرجى تأكيد بريدك الإلكتروني أولاً.',
  );
  String get tooManyRequests => _translated(
    'Слишком много попыток. Подождите немного и повторите.',
    'Too many attempts. Wait a moment and try again.',
    'عدد المحاولات كبير جداً. انتظر قليلاً ثم حاول مرة أخرى.',
  );
  String get sessionExpired => _translated(
    'Сессия завершена. Войдите снова.',
    'Your session has expired. Please sign in again.',
    'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى.',
  );
  String get notFoundError => _translated(
    'Запрошенные данные не найдены.',
    'The requested information could not be found.',
    'تعذر العثور على المعلومات المطلوبة.',
  );
  String get conflictError => _translated(
    'Эти данные уже существуют.',
    'This information already exists.',
    'هذه المعلومات موجودة بالفعل.',
  );
  String get serverError => _translated(
    'Сервис временно недоступен. Повторите попытку позже.',
    'The service is temporarily unavailable. Please try again later.',
    'الخدمة غير متاحة مؤقتاً. حاول مرة أخرى لاحقاً.',
  );
  String get configurationError => _translated(
    'Приложение не подключено к серверу.',
    'The app is not connected to the server.',
    'التطبيق غير متصل بالخادم.',
  );
  String get changeBranch =>
      _translated('Сменить филиал', 'Change branch', 'تغيير الفرع');
  String get selectBranch =>
      _translated('Выберите филиал', 'Select a branch', 'اختر فرعاً');
  String get selectBranchLater => _translated(
    'Вы можете изменить выбор позже в меню.',
    'You can change your selection later from the menu.',
    'يمكنك تغيير اختيارك لاحقاً من القائمة.',
  );
  String get cartClearedForBranch => _translated(
    'Корзина очищена: цены и доступность зависят от филиала.',
    'Cart cleared because prices and availability depend on the branch.',
    'تم إفراغ السلة لأن الأسعار والتوفر يعتمدان على الفرع.',
  );
  String saveLanguageFailed(Object error) => _translated(
    'Не удалось сохранить язык: $error',
    'Could not save language: $error',
    'تعذر حفظ اللغة: $error',
  );
  String get spicy => _translated('Острое', 'Spicy', 'حار');
  String get vegetarian => _translated('Вегетарианское', 'Vegetarian', 'نباتي');
  String get popular => _translated('Популярное', 'Popular', 'شائع');
  String get sizeOrVariant =>
      _translated('Размер / вариант', 'Size / option', 'الحجم / الخيار');
  String sandwichType(String code) {
    switch (code) {
      case 'chicken':
        return _translated('КУРИЦА', 'CHICKEN', 'دجاج');
      case 'lamb':
        return _translated('БАРАНИНА', 'LAMB', 'لحم ضأن');
      case 'beef':
        return _translated('ГОВЯДИНА', 'BEEF', 'لحم بقر');
      case 'sandwiches':
        return _translated('СЭНДВИЧИ', 'SANDWICHES', 'ساندويتشات');
      default:
        return code;
    }
  }

  String get selectUpToOne => _translated(
    'Выберите до одного варианта',
    'Choose up to one option',
    'اختر خياراً واحداً كحد أقصى',
  );
  String selectUpTo(int count) => _translated(
    'Выберите до $count вариантов',
    'Choose up to $count options',
    'اختر حتى $count خيارات',
  );
  String get checkoutTitle =>
      _translated('Оформление заказа', 'Checkout', 'إتمام الطلب');
  String get accountContactRequired => _translated(
    'Для оформления заказа нужны имя и номер телефона в аккаунте.',
    'Add your name and phone number to your account before placing an order.',
    'أضف اسمك ورقم هاتفك إلى حسابك قبل تقديم الطلب.',
  );
  String get pickupOrder =>
      _translated('Получение заказа', 'Order pickup', 'استلام الطلب');
  String get pickupTime =>
      _translated('Время получения', 'Pickup time', 'وقت الاستلام');
  String get schedulePickup => _translated(
    'Запланировать на время',
    'Schedule for a time',
    'تحديد وقت للاستلام',
  );
  String get asSoonAsReady => _translated(
    'Как только заказ будет готов',
    'As soon as the order is ready',
    'بمجرد أن يصبح الطلب جاهزاً',
  );
  String get chooseTime =>
      _translated('Выбрать время', 'Choose time', 'اختر الوقت');
  String get chooseFutureTime => _translated(
    'Выберите время в будущем',
    'Choose a future time',
    'اختر وقتاً في المستقبل',
  );
  String get contactDetails =>
      _translated('Контактные данные', 'Contact details', 'بيانات الاتصال');
  String get payment => _translated('Оплата', 'Payment', 'الدفع');
  String get cashAtPickup => _translated(
    'Наличными при получении',
    'Cash on pickup',
    'نقداً عند الاستلام',
  );
  String get onlinePaymentLater => _translated(
    'Онлайн-оплата будет добавлена позже',
    'Online payment will be added later',
    'ستتم إضافة الدفع الإلكتروني لاحقاً',
  );
  String get orderComment =>
      _translated('Комментарий к заказу', 'Order comment', 'ملاحظة للطلب');
  String get orderCommentHint => _translated(
    'Например: позвонить при готовности',
    'For example: call when ready',
    'مثال: اتصل عند الجاهزية',
  );
  String get yourOrder => _translated('Ваш заказ', 'Your order', 'طلبك');
  String get emailConfirmationSent => _translated(
    'Мы отправили ссылку для подтверждения на ваш email. Подтвердите адрес, затем войдите в приложение.',
    'We sent a confirmation link to your email. Confirm your address, then sign in.',
    'أرسلنا رابط تأكيد إلى بريدك الإلكتروني. أكّد عنوانك ثم سجّل الدخول.',
  );
  String get invalidPhone => _translated(
    'Введите корректный номер телефона',
    'Enter a valid phone number',
    'أدخل رقم هاتف صحيحاً',
  );

  // ── Category translations (from JSON ru → en) ──
  static const Map<String, String> _categoryEnTranslations = {
    'ПИЦЦА': 'PIZZA',
    'БЛИНЧИКИ': 'FATAYER',
    'КАЛЬЦОНЕ': 'CALZONE',
    'СЭНДВИЧИ': 'SANDWICHES',
    'БЛЮДА': 'DISHES',
    'САЛАТЫ': 'SALADS',
    'ФРУКТОВЫЕ САЛАТЫ': 'FRUIT SALADS',
    'МОРОЖЕНОЕ': 'ICE CREAM',
    'МОЛОЧНЫЕ КОКТЕЙЛИ': 'MILKSHAKES',
    'ЦИТРУСОВЫЙ ФРЕШ': 'CITRUS FRESH',
    'СМУЗИ': 'SMOOTHIES',
    'КОФЕ/ЧАЙ': 'COFFEE/TEA',
  };

  String translateCategory(String ruName) {
    if (isRussian) return ruName;
    if (isArabic) return _categoryArTranslations[ruName] ?? ruName;
    return _categoryEnTranslations[ruName] ?? ruName;
  }

  static const Map<String, String> _categoryArTranslations = {
    'ПИЦЦА': 'بيتزا',
    'БЛИНЧИКИ': 'فطائر',
    'КАЛЬЦОНЕ': 'كالزوني',
    'СЭНДВИЧИ': 'ساندويتشات',
    'БЛЮДА': 'أطباق',
    'САЛАТЫ': 'سلطات',
    'ФРУКТОВЫЕ САЛАТЫ': 'سلطات الفواكه',
    'МОРОЖЕНОЕ': 'آيس كريم',
    'МОЛОЧНЫЕ КОКТЕЙЛИ': 'مخفوقات الحليب',
    'ЦИТРУСОВЫЙ ФРЕШ': 'مشروبات حمضيات طازجة',
    'СМУЗИ': 'سموذي',
    'КОФЕ/ЧАЙ': 'قهوة وشاي',
  };
}
