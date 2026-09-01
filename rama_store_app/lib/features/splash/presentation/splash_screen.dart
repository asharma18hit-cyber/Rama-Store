import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.primaryGold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 72,
                      color: AppColors.primaryGoldLight,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    AppConstants.appName.toUpperCase(),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          letterSpacing: 4,
                          color: AppColors.primaryGoldLight,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 2,
                    width: 60,
                    color: AppColors.primaryGold,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appTagline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  AppButton(
                    text: 'Enter Store Front',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    text: 'Sign In / Register',
                    isOutlined: true,
                    onPressed: () => context.go('/auth'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
