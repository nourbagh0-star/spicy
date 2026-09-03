import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spicy/core/error/error_mapper.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';

class AppErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  const AppErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: compact ? 36 : 52,
          color: AppTheme.error,
        ),
        const SizedBox(height: 14),
        Text(
          locale.somethingWentWrong,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          AppErrorMapper.message(error, locale),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondary),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(locale.retry),
          ),
        ],
      ],
    );

    if (compact) return content;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: content,
        ),
      ),
    );
  }
}
