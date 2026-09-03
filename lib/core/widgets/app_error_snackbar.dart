import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spicy/core/error/error_mapper.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';

class AppErrorSnackBar {
  const AppErrorSnackBar._();

  static void show(BuildContext context, Object error) {
    final locale = context.read<AppLocale>();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppErrorMapper.message(error, locale),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
