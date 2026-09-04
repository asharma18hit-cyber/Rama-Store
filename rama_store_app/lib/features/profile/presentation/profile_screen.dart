import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/hover_card.dart';
import '../../../main.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final loyaltyPoints = ref.watch(loyaltyRepositoryProvider).getStoredPoints();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF3525CD)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'MY ACCOUNT & PROFILE',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF3525CD)),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64.0 : 16.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Header Bento Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC7C4D8), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3525CD),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3525CD).withValues(alpha: 0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user != null && user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : 'R',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullname.isNotEmpty == true ? user!.fullname : 'Rama Store Member',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0B1C30)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.emailOrPhone.isNotEmpty == true ? user!.emailOrPhone : 'Guest Session',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF464555)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF4FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF3525CD)),
                              ),
                              child: Text(
                                user?.isAdmin == true ? '👑 STORE OWNER / ADMINISTRATOR' : '⚡ EMERALD TIER MEMBER',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF3525CD)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Loyalty Points Balance Bento
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryFixedDim.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.stars_rounded, color: AppColors.secondaryFixedDim, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Loyalty Cashback Coins', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              Text('10% Cashback applied on orders', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '${loyaltyPoints.toStringAsFixed(0)} PTS',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondaryFixedDim),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'STORE SERVICES',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),

                // Menu items
                _buildMenuItem(
                  icon: Icons.receipt_long_rounded,
                  title: 'Order History & Tracking',
                  subtitle: 'View live fulfillment timelines and invoices',
                  onTap: () => context.push('/orders'),
                ),
                const SizedBox(height: 10),

                _buildMenuItem(
                  icon: Icons.favorite_rounded,
                  title: 'My Wishlist',
                  subtitle: 'Saved items for later purchase',
                  onTap: () => context.push('/wishlist'),
                ),
                const SizedBox(height: 10),

                _buildMenuItem(
                  icon: Icons.download_rounded,
                  title: 'Download Native Android App',
                  subtitle: 'Install APK directly on your mobile device',
                  onTap: () => context.push('/downloads'),
                ),
                const SizedBox(height: 10),

                if (user?.isAdmin == true) ...[
                  _buildMenuItem(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Administrator Dashboard',
                    subtitle: 'Manage products, publishing, stock and orders',
                    highlight: true,
                    onTap: () => context.push('/admin'),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 24),

                // Auth Action
                if (authState.isAuthenticated)
                  AppButton(
                    text: 'Sign Out Account',
                    icon: Icons.logout_rounded,
                    isOutlined: true,
                    onPressed: () async {
                      await ref.read(authNotifierProvider.notifier).logout();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signed out successfully')),
                        );
                      }
                    },
                  )
                else
                  AppButton(
                    text: 'Sign In / Register',
                    icon: Icons.login_rounded,
                    onPressed: () => context.push('/auth'),
                  ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return HoverCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: highlight ? AppColors.secondaryFixedDim : const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: highlight ? AppColors.secondaryFixedDim.withValues(alpha: 0.15) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: highlight ? AppColors.secondaryFixedDim : AppColors.primaryFixedDim, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: highlight ? AppColors.secondaryFixedDim : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
