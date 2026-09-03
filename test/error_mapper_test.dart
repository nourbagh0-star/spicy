import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spicy/core/error/app_failure.dart';
import 'package:spicy/core/error/error_mapper.dart';
import 'package:spicy/core/locale/app_locale.dart';

void main() {
  group('AppErrorMapper', () {
    test('maps network errors to a safe localized message', () {
      final locale = AppLocale();

      final failure = AppErrorMapper.toFailure(
        Exception('SocketException: Failed host lookup'),
      );

      expect(failure.type, AppFailureType.network);
      expect(AppErrorMapper.message(failure, locale), locale.networkError);
    });

    test('maps invalid credentials without exposing technical details', () {
      final locale = AppLocale();

      final failure = AppErrorMapper.toFailure(
        Exception('AuthException: Invalid login credentials'),
      );

      expect(failure.type, AppFailureType.invalidCredentials);
      expect(
        AppErrorMapper.message(failure, locale),
        locale.invalidCredentials,
      );
    });

    test('returns messages for the selected language', () {
      final locale = AppLocale();
      locale.setLocale(const Locale('en'));

      expect(
        AppErrorMapper.message(
          const AppFailure(
            type: AppFailureType.timeout,
            technicalMessage: 'request timeout',
          ),
          locale,
        ),
        locale.timeoutError,
      );
    });

    test('uses a generic message for unknown failures', () {
      final locale = AppLocale();

      final failure = AppErrorMapper.toFailure(Exception('internal detail'));

      expect(failure.type, AppFailureType.unknown);
      expect(
        AppErrorMapper.message(failure, locale),
        locale.somethingWentWrong,
      );
    });
  });
}
