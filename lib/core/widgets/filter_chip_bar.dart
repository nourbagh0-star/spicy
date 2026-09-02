import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spicy/core/design/app_motion.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';

class FilterChipBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;
  final String Function(String value)? labelBuilder;

  const FilterChipBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          final label =
              labelBuilder?.call(category) ??
              (category == 'All' ? locale.allCategories : category);
          return Semantics(
            button: true,
            selected: isSelected,
            label: label,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              child: InkWell(
                onTap: () => onSelected(category),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.standard),
                  curve: AppMotion.standardCurve,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.onBackground
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.onBackground
                          : AppTheme.outline.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isSelected ? AppTheme.surface : AppTheme.secondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
