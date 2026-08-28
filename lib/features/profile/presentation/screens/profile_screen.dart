import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/app_button.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:spicy/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:spicy/features/profile/presentation/cubit/profile_state.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_state.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_cubit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          locale.profile,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (state is ProfileLoaded) {
            final profile = state.profile;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      profile.name[0].toUpperCase(),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Language Toggle
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    title: locale.language,
                    subtitle: locale.languageName,
                    onTap: () => _showLanguagePicker(locale),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      _StatCard(
                        label: locale.orders,
                        value: '${profile.totalOrders}',
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const SizedBox(width: 16),
                      _StatCard(
                        label: locale.reviews,
                        value: '${profile.totalReviews}',
                        icon: Icons.star_outline_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Settings list
                  _SettingsTile(
                    icon: Icons.location_on_outlined,
                    title: locale.deliveryAddress,
                    subtitle: profile.address,
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.phone_outlined,
                    title: locale.phone,
                    subtitle: profile.phone,
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.receipt_long_outlined,
                    title: locale.orderHistory,
                    subtitle: locale.viewPastOrders,
                    onTap: () => context.push('/orders'),
                  ),
                  _SettingsTile(
                    icon: Icons.rate_review_outlined,
                    title: locale.myReviews,
                    subtitle: locale.manageReviews,
                    onTap: () => context.push('/reviews'),
                  ),
                  const SizedBox(height: 32),

                  AppButton(
                    label: locale.leaveReview,
                    icon: Icons.edit_rounded,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.push('/review/new'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<AuthCubit>().logout();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(
                        locale.logout,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusDefault,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _showLanguagePicker(AppLocale locale) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: locale.languageCode,
              onChanged: (value) => Navigator.pop(sheetContext, value),
              child: const Column(
                children: [
                  RadioListTile(value: 'ru', title: Text('Русский')),
                  RadioListTile(value: 'en', title: Text('English')),
                  RadioListTile(value: 'ar', title: Text('العربية')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || selected == locale.languageCode) return;

    try {
      await locale.selectLanguage(selected);
      if (!mounted) return;
      final branchState = context.read<BranchCubit>().state;
      if (branchState is BranchLoaded && branchState.selectedBranch != null) {
        await context.read<MenuCubit>().loadMenu(
          branchState.selectedBranch!.id,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AppLocale>().saveLanguageFailed(error)),
        ),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: const Color(0x1A6B6661)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBackground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
