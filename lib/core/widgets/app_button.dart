import 'package:flutter/material.dart';
import 'package:spicy/core/theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outlined }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.primary:
        return SizedBox(
          width: width,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
            ),
            child: _buildChild(AppTheme.onPrimary),
          ),
        );
      case AppButtonVariant.secondary:
        return SizedBox(
          width: width,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceDim,
              foregroundColor: AppTheme.onBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
            ),
            child: _buildChild(AppTheme.onBackground),
          ),
        );
      case AppButtonVariant.outlined:
        return SizedBox(
          width: width,
          height: 48,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              side: const BorderSide(color: AppTheme.outline, width: 1),
            ),
            child: _buildChild(AppTheme.primary),
          ),
        );
    }
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    return Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
  }
}
