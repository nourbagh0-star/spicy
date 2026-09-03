import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/design/app_motion.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/widgets/app_button.dart';
import 'package:spicy/core/widgets/app_error_snackbar.dart';
import 'package:spicy/core/widgets/responsive_content.dart';
import 'package:spicy/features/reviews/presentation/cubit/reviews_cubit.dart';
import 'package:spicy/features/reviews/presentation/cubit/reviews_state.dart';

class LeaveReviewScreen extends StatefulWidget {
  final String orderId;
  final String branchId;

  const LeaveReviewScreen({
    super.key,
    required this.orderId,
    required this.branchId,
  });

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final isValidOrder =
        widget.orderId.isNotEmpty && widget.branchId.isNotEmpty;
    return BlocListener<ReviewsCubit, ReviewsState>(
      listener: (context, state) {
        if (state is ReviewSubmitted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(locale.reviewSubmitted)));
          context.go('/reviews');
        }
        if (state is ReviewsError) {
          AppErrorSnackBar.show(context, state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(locale.reviewBranch)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ResponsiveContent(
                    maxWidth: 720,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.howWasOrder,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(locale.reviewHelps),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 4,
                          children: List.generate(5, (index) {
                            final value = index + 1;
                            final selected = value <= _rating;
                            return Semantics(
                              button: true,
                              selected: _rating == value,
                              label: '$value / 5',
                              child: IconButton(
                                tooltip: '$value / 5',
                                onPressed: () =>
                                    setState(() => _rating = value),
                                icon: AnimatedScale(
                                  duration: AppMotion.duration(
                                    context,
                                    AppMotion.fast,
                                  ),
                                  scale: _rating == value ? 1.12 : 1,
                                  child: Icon(
                                    selected
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 38,
                                    color: const Color(0xFFF9A825),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _commentController,
                          maxLength: 1000,
                          minLines: 4,
                          maxLines: 7,
                          textInputAction: TextInputAction.newline,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: locale.yourReview,
                            hintText: locale.tellUs,
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ResponsiveContent(
                maxWidth: 720,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: BlocBuilder<ReviewsCubit, ReviewsState>(
                  builder: (context, state) => AppButton(
                    label: locale.submitReview,
                    icon: Icons.send_rounded,
                    isLoading: state is ReviewSubmitting,
                    onPressed:
                        isValidOrder &&
                            _rating > 0 &&
                            _commentController.text.trim().isNotEmpty
                        ? () => context.read<ReviewsCubit>().submitReview(
                            orderId: widget.orderId,
                            branchId: widget.branchId,
                            rating: _rating,
                            comment: _commentController.text,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
