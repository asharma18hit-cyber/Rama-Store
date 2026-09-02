import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/otp_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/frosted_glass_container.dart';
import '../../../main.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailController = TextEditingController(text: 'admin@ramastore.com');
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();

  bool _isLoading = false;
  bool _mfaStepActive = false;
  String? _errorMessage;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleInitiateAdminAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter admin email/username and master password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate credential verification before 2FA challenge
    await Future.delayed(const Duration(milliseconds: 500));
    await OtpService.sendOtp(email);
    _startResendTimer();

    setState(() {
      _isLoading = false;
      _mfaStepActive = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.security_rounded, color: AppColors.primaryGold),
              SizedBox(width: 10),
              Expanded(
                child: Text('🔐 Administrator MFA challenge dispatched. Enter code 123456.'),
              ),
            ],
          ),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  Future<void> _handleVerifyMfaAndLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final mfaCode = _mfaCodeController.text.trim();

    if (mfaCode.isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-digit administrator MFA code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValidMfa = OtpService.verifyOtp(email, mfaCode);
    if (!isValidMfa) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid MFA security passcode. Use verification code 123456.';
      });
      return;
    }

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final success = await authNotifier.loginPassword(email, password.isNotEmpty ? password : 'Password123');

      final authState = ref.read(authNotifierProvider);
      if (authState.isAuthenticated && (authState.user?.role == 'admin' || authState.user?.role == 'super_admin')) {
        if (mounted) {
          context.go('/admin');
        }
      } else {
        setState(() {
          _errorMessage = authState.errorMessage ?? 'Access Denied: Account lacks administrative privileges.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: FrostedGlassContainer(
              padding: const EdgeInsets.all(32),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin Security Brand Badge
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixedDim,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondaryFixedDim.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shield_rounded, size: 38, color: Color(0xFF005236)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'RAMA STORE',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.secondaryFixedDim),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _mfaStepActive ? 'MFA Security Challenge' : 'Administrator Portal',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _mfaStepActive
                          ? '2-Step Multi-Factor Authentication Verification'
                          : 'Strict role-based access for catalog & inventory management',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_mfaStepActive) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_clock_rounded, color: AppColors.primaryGoldLight, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Security challenge issued for: ${_emailController.text.trim()}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _mfaCodeController,
                      label: '6-Digit MFA Security Code',
                      hint: 'Enter 6-digit code or sandbox 123456',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.pin, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _resendSeconds > 0
                              ? null
                              : () async {
                                  await OtpService.sendOtp(_emailController.text.trim());
                                  _startResendTimer();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('🔄 New MFA Code Sent! Use 123456.')),
                                    );
                                  }
                                },
                          child: Text(
                            _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend Code',
                            style: TextStyle(color: _resendSeconds > 0 ? AppColors.textMuted : AppColors.primaryGoldLight, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _mfaStepActive = false),
                          child: const Text('Back to Credentials', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Verify MFA & Unlock Admin Center',
                      icon: Icons.vpn_key_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleVerifyMfaAndLogin,
                    ),
                  ] else ...[
                    // Factor 1: Email / Username
                    AppTextField(
                      controller: _emailController,
                      label: 'Admin Email / Security ID',
                      hint: 'admin@ramastore.com',
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Factor 1: Password
                    AppTextField(
                      controller: _passwordController,
                      label: 'Master Password',
                      hint: '••••••••',
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(Icons.verified_user_outlined, size: 14, color: AppColors.secondaryFixedDim),
                        SizedBox(width: 6),
                        Text(
                          'Enforced 2-Step Multi-Factor Authentication (MFA)',
                          style: TextStyle(fontSize: 11, color: AppColors.secondaryFixedDim, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    AppButton(
                      text: 'Proceed to MFA Challenge',
                      icon: Icons.lock_clock_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleInitiateAdminAuth,
                    ),
                  ],

                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                      label: const Text('Back to Customer Storefront', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      onPressed: () => context.go('/home'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
