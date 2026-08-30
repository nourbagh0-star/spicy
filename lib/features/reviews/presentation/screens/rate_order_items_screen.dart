import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/app_button.dart';
import 'package:spicy/features/reviews/domain/entities/reviewable_order_item.dart';
import 'package:spicy/features/reviews/presentation/cubit/reviews_cubit.dart';
import 'package:spicy/features/reviews/presentation/cubit/reviews_state.dart';

class RateOrderItemsScreen extends StatefulWidget {
  final String orderId;

  const RateOrderItemsScreen({super.key, required this.orderId});

  @override
  State<RateOrderItemsScreen> createState() => _RateOrderItemsScreenState();
}

class _RateOrderItemsScreenState extends State<RateOrderItemsScreen> {
  final Map<String, int> _ratings = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadItems();
    });
  }

  void _loadItems() {
    context.read<ReviewsCubit>().loadReviewableOrderItems(
      orderId: widget.orderId,
      languageCode: context.read<AppLocale>().languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return BlocListener<ReviewsCubit, ReviewsState>(
      listener: (context, state) {
        if (state is ItemRatingsSubmitted) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(locale.itemRatingsSubmitted)));
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(locale.rateItemsTitle)),
        body: BlocBuilder<ReviewsCubit, ReviewsState>(
          builder: (context, state) {
            if (state is ItemRatingsLoading || state is ReviewsInitial) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (state is ReviewsError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 44,
                        color: AppTheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _loadItems,
                        child: Text(locale.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is ItemRatingsLoaded || state is ItemRatingsSubmitting) {
              final items = state is ItemRatingsLoaded
                  ? state.items
                  : const <ReviewableOrderItem>[];
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      locale.noItemsToRate,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return _RatingForm(
                items: items,
                ratings: _ratings,
                isSubmitting: state is ItemRatingsSubmitting,
                onRatingChanged: (itemId, rating) =>
                    setState(() => _ratings[itemId] = rating),
                onSubmit: () {
                  if (_ratings.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(locale.selectAtLeastOneItemRating),
                      ),
                    );
                    return;
                  }
                  context.read<ReviewsCubit>().submitItemRatings(
                    orderId: widget.orderId,
                    ratings: _ratings,
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _RatingForm extends StatelessWidget {
  final List<ReviewableOrderItem> items;
  final Map<String, int> ratings;
  final bool isSubmitting;
  final void Function(String itemId, int rating) onRatingChanged;
  final VoidCallback onSubmit;

  const _RatingForm({
    required this.items,
    required this.ratings,
    required this.isSubmitting,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final pendingItems = items.where((item) => !item.alreadyRated).toList();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              locale.rateItemsSubtitle,
              style: GoogleFonts.inter(color: AppTheme.secondary),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ItemRatingCard(
                item: items[index],
                selectedRating: ratings[items[index].orderItemId] ?? 0,
                onRatingChanged: onRatingChanged,
              ),
            ),
          ),
          if (pendingItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: AppButton(
                label: locale.submitReview,
                icon: Icons.send_rounded,
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : onSubmit,
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemRatingCard extends StatelessWidget {
  final ReviewableOrderItem item;
  final int selectedRating;
  final void Function(String itemId, int rating) onRatingChanged;

  const _ItemRatingCard({
    required this.item,
    required this.selectedRating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0x1A6B6661)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.imageUrl.isEmpty
                  ? const ColoredBox(
                      color: AppTheme.surfaceDim,
                      child: Icon(Icons.restaurant_outlined),
                    )
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppTheme.surfaceDim,
                        child: Icon(Icons.restaurant_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity} × ${item.name}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                if (item.variantName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.variantName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (item.alreadyRated)
                  Text(
                    context.watch<AppLocale>().reviewSubmitted,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF2E7D32),
                    ),
                  )
                else
                  Wrap(
                    spacing: 1,
                    children: List.generate(
                      5,
                      (index) => InkResponse(
                        onTap: () =>
                            onRatingChanged(item.orderItemId, index + 1),
                        radius: 22,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            index < selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFF9A825),
                            size: 27,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
