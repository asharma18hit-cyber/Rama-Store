import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../main.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyaltyRepo = ref.watch(loyaltyRepositoryProvider);
    final points = loyaltyRepo.getStoredPoints();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rama Loyalty & Rewards'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Points Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFB45309)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('LOYALTY REWARDS BALANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                      Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${points.toStringAsFixed(0)} PTS',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Equivalent to ₹${points.toStringAsFixed(0)} discount on your next checkout',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text('10% Cash-Back Program Policy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Every time you complete a order on Rama Store (mobile app or live website), 10% of your total order amount is instantly credited as loyalty points to your account.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),

            const SizedBox(height: 32),
            const Text('How It Works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            _buildStepItem(
              stepNumber: '1',
              title: 'Create Account / Sign In',
              description: 'Your loyalty points wallet is linked automatically across mobile app and web frontend.',
            ),
            const SizedBox(height: 16),
            _buildStepItem(
              stepNumber: '2',
              title: 'Shop & Place Orders',
              description: 'Select products from Bakery, Books, Medicine, Groceries, Sports & Stationery.',
            ),
            const SizedBox(height: 16),
            _buildStepItem(
              stepNumber: '3',
              title: 'Redeem Instantly at Checkout',
              description: 'Check the "Apply Loyalty Points" box in your Cart screen to deduct points as a real Rupee discount!',
            ),

            const SizedBox(height: 36),
            AppButton(
              text: 'Start Shopping Now',
              icon: Icons.shopping_bag,
              onPressed: () => context.go('/catalog'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem({required String stepNumber, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.primaryGold,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(stepNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
