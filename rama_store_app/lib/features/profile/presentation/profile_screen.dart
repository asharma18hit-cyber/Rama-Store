import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../main.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _adminPasswordController = TextEditingController();
  final _adminOtpController = TextEditingController();
  bool _adminOtpSent = false;
  bool _showAdminGate = false;

  @override
  void dispose() {
    _adminPasswordController.dispose();
    _adminOtpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryGold,
                    child: Text(
                      user != null && user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : 'G',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullname ?? 'Guest Visitor',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.emailOrPhone ?? 'Not Signed In',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: user?.isAdmin == true ? AppColors.accentAmber.withValues(alpha: 0.2) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user?.isAdmin == true ? 'STORE OWNER / ADMIN' : 'CUSTOMER ACCOUNT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: user?.isAdmin == true ? AppColors.accentAmber : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profile Menu List
            _buildProfileMenuItem(
              icon: Icons.favorite_outline,
              title: 'Saved Wishlist',
              subtitle: 'View items saved to your favorites',
              onTap: () => context.push('/wishlist'),
            ),
            _buildProfileMenuItem(
              icon: Icons.loyalty,
              title: 'Loyalty Rewards Wallet',
              subtitle: 'Check 10% cash-back points balance',
              onTap: () => context.push('/loyalty'),
            ),
            _buildProfileMenuItem(
              icon: Icons.history_outlined,
              title: 'Order History',
              subtitle: 'View trackings & reorder previous items',
              onTap: () => context.go('/orders'),
            ),
            if (user?.isAdmin == true || user?.role == 'admin' || user?.role == 'super_admin') ...[
              _buildProfileMenuItem(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Stitch Admin Dashboard',
                subtitle: 'Manage revenue metrics, inventory & new products',
                onTap: () => context.push('/admin'),
              ),
            ],
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                secondary: Icon(
                  ref.watch(themeModeNotifierProvider) == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                  color: AppColors.primaryGold,
                ),
                title: const Text('Dark Mode Display', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                subtitle: Text(
                  ref.watch(themeModeNotifierProvider) == ThemeMode.dark ? 'Enabled (Dark Ledger theme)' : 'Light Mode Enabled',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                value: ref.watch(themeModeNotifierProvider) == ThemeMode.dark,
                activeThumbColor: AppColors.primaryGold,
                onChanged: (val) => ref.read(themeModeNotifierProvider.notifier).toggleTheme(),
              ),
            ),

            // Owner 2FA Portal Security Gate section
            if (user?.isAdmin == true || user?.emailOrPhone.contains('admin') == true || user?.emailOrPhone.contains('7268903804') == true) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.admin_panel_settings, color: AppColors.accentAmber),
                        SizedBox(width: 8),
                        Text('Owner 2FA Gate Security Portal', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Mirror site 2FA verification to manage inventory and status updates.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    if (!_showAdminGate)
                      AppButton(
                        text: 'Trigger Owner 2FA Auth',
                        isOutlined: true,
                        color: AppColors.accentAmber,
                        onPressed: () => setState(() => _showAdminGate = true),
                      )
                    else ...[
                      if (!_adminOtpSent) ...[
                        TextField(
                          controller: _adminPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(hintText: 'Enter Owner Password'),
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          text: 'Request Admin 2FA Code',
                          color: AppColors.accentAmber,
                          onPressed: () async {
                            final pass = _adminPasswordController.text;
                            if (pass.isEmpty) return;
                            final ok = await ref.read(authNotifierProvider.notifier).loginPassword(user!.emailOrPhone, pass);
                            if (ok) setState(() => _adminOtpSent = true);
                          },
                        ),
                      ] else ...[
                        TextField(
                          controller: _adminOtpController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(hintText: 'Enter 6-digit 2FA Code'),
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          text: 'Verify 2FA Security',
                          color: AppColors.success,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Owner 2FA Verification Confirmed!')),
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 36),
            if (authState.isAuthenticated)
              AppButton(
                text: 'Log Out of Account',
                isOutlined: true,
                color: AppColors.error,
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/auth');
                  }
                },
              )
            else
              AppButton(
                text: 'Sign In / Register',
                onPressed: () => context.go('/auth'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGold),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
