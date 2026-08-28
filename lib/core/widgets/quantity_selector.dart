import 'package:flutter/material.dart';
import 'package:spicy/core/theme/app_theme.dart';

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.outline.withValues(alpha: 0.3)),
          color: AppTheme.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildButton(
              icon: Icons.remove,
              onTap: quantity > min ? () => onChanged(quantity - 1) : null,
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 40),
              alignment: Alignment.center,
              child: Text(
                '$quantity',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onBackground,
                ),
              ),
            ),
            _buildButton(
              icon: Icons.add,
              onTap: quantity < max ? () => onChanged(quantity + 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: onTap != null
                ? AppTheme.primary
                : AppTheme.outline.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
