import 'dart:async';

import 'package:spicy/core/error/app_failure.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppErrorMapper {
  const AppErrorMapper._();

  static AppFailure toFailure(Object error) {
    if (error is AppFailure) return error;

    final technicalMessage = error.toString();
    final normalized = technicalMessage.toLowerCase();

    if (error is TimeoutException || normalized.contains('timed out')) {
      return AppFailure(
        type: AppFailureType.timeout,
        technicalMessage: technicalMessage,
      );
    }

    if (_looksLikeNetworkError(normalized)) {
      return AppFailure(
        type: AppFailureType.network,
        technicalMessage: technicalMessage,
      );
    }

    if (normalized.contains('not connected to supabase') ||
        normalized.contains('not connected to the server')) {
      return AppFailure(
        type: AppFailureType.configuration,
        technicalMessage: technicalMessage,
      );
    }

    if (error is AuthException || normalized.contains('authexception')) {
      if (normalized.contains('invalid login credentials') ||
          normalized.contains('invalid email or password')) {
        return AppFailure(
          type: AppFailureType.invalidCredentials,
          technicalMessage: technicalMessage,
        );
      }
      if (normalized.contains('email not confirmed')) {
        return AppFailure(
          type: AppFailureType.emailNotConfirmed,
          technicalMessage: technicalMessage,
        );
      }
      if (normalized.contains('rate limit') ||
          normalized.contains('too many requests')) {
        return AppFailure(
          type: AppFailureType.rateLimited,
          technicalMessage: technicalMessage,
        );
      }
      return AppFailure(
        type: AppFailureType.unauthorized,
        technicalMessage: technicalMessage,
      );
    }

    if (error is PostgrestException || normalized.contains('postgrest')) {
      final code = error is PostgrestException ? error.code : '';
      if (code == '23505') {
        return AppFailure(
          type: AppFailureType.conflict,
          technicalMessage: technicalMessage,
        );
      }
      if (code == 'PGRST116') {
        return AppFailure(
          type: AppFailureType.notFound,
          technicalMessage: technicalMessage,
        );
      }
      if (code == '42501') {
        return AppFailure(
          type: AppFailureType.unauthorized,
          technicalMessage: technicalMessage,
        );
      }
      return AppFailure(
        type: AppFailureType.server,
        technicalMessage: technicalMessage,
      );
    }

    if (error is StorageException ||
        error is FunctionException ||
        normalized.contains('storageexception') ||
        normalized.contains('functionexception')) {
      return AppFailure(
        type: AppFailureType.server,
        technicalMessage: technicalMessage,
      );
    }

    if (normalized.contains('please sign in') ||
        normalized.contains('not authenticated') ||
        normalized.contains('jwt expired')) {
      return AppFailure(
        type: AppFailureType.unauthorized,
        technicalMessage: technicalMessage,
      );
    }
    if (normalized.contains('not found')) {
      return AppFailure(
        type: AppFailureType.notFound,
        technicalMessage: technicalMessage,
      );
    }

    return AppFailure(
      type: AppFailureType.unknown,
      technicalMessage: technicalMessage,
    );
  }

  static String message(Object error, AppLocale locale) {
    return switch (toFailure(error).type) {
      AppFailureType.network => locale.networkError,
      AppFailureType.timeout => locale.timeoutError,
      AppFailureType.invalidCredentials => locale.invalidCredentials,
      AppFailureType.emailNotConfirmed => locale.emailNotConfirmed,
      AppFailureType.rateLimited => locale.tooManyRequests,
      AppFailureType.unauthorized => locale.sessionExpired,
      AppFailureType.notFound => locale.notFoundError,
      AppFailureType.conflict => locale.conflictError,
      AppFailureType.server => locale.serverError,
      AppFailureType.configuration => locale.configurationError,
      AppFailureType.unknown => locale.somethingWentWrong,
    };
  }

  static bool _looksLikeNetworkError(String message) {
    return message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('failed host lookup') ||
        message.contains('network request failed') ||
        message.contains('xmlhttprequest error') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('network is unreachable');
  }
}
