import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../core/services/otp_service.dart';
import '../../../main.dart';
import 'auth_notifier.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const AuthScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form Controllers
  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _mfaCodeController = TextEditingController();

  final _otpPhoneController = TextEditingController();
  final _otpCodeController = TextEditingController();

  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regOtpController = TextEditingController();

  final _forgotEmailController = TextEditingController();
  final _forgotOtpController = TextEditingController();
  final _forgotNewPassController = TextEditingController();

  bool _rememberDevice = true;
  bool _requireMfa = true;
  bool _mfaStepActive = false;
  bool _otpSentForLogin = false;
  bool _otpSentForReg = false;
  bool _otpSentForForgot = false;
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _tabController.dispose();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _mfaCodeController.dispose();
    _otpPhoneController.dispose();
    _otpCodeController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regOtpController.dispose();
    _forgotEmailController.dispose();
    _forgotOtpController.dispose();
    _forgotNewPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.error),
        );
      }
      if (next.infoMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.infoMessage!), backgroundColor: AppColors.success),
        );
      }
      if (next.isAuthenticated) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rama Store Security & Auth'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGold,
          labelColor: AppColors.primaryGoldLight,
          unselectedLabelColor: AppColors.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Credentials + MFA'),
            Tab(text: 'Passwordless OTP'),
            Tab(text: 'Create Account'),
            Tab(text: 'Reset Password'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.primaryGoldLight, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Rama Store Enterprise Identity & MFA',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          '2-Factor Authentication protection with instant verification',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPasswordMfaLoginTab(authState),
                  _buildOtpLoginTab(authState),
                  _buildRegisterTab(authState),
                  _buildForgotPasswordTab(authState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordMfaLoginTab(AuthState authState) {
    if (_mfaStepActive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, color: AppColors.primaryGoldLight, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔐 Step 2: Multi-Factor Authentication (MFA)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Security challenge issued for: ${_loginIdentifierController.text.trim()}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _mfaCodeController,
            label: '6-Digit MFA Security Code',
            hint: 'Enter 6-digit code',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.security_rounded, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'We sent a 2FA verification passcode to your registered device. Enter the code above to finalize authentication.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          AppButton(
            text: 'Verify MFA Code & Enter Store',
            isLoading: authState.isLoading,
            onPressed: () {
              final code = _mfaCodeController.text.trim();
              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter the 6-digit MFA security code')),
                );
                return;
              }
              final result = OtpService.verifyOtp(_loginIdentifierController.text.trim(), code);
              if (result.isValid) {
                ref.read(authNotifierProvider.notifier).loginPassword(
                      _loginIdentifierController.text.trim(),
                      _loginPasswordController.text,
                    );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.error ?? 'Invalid MFA security code. Please check and try again.'), backgroundColor: AppColors.error),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Credentials'),
              onPressed: () => setState(() => _mfaStepActive = false),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        AppTextField(
          controller: _loginIdentifierController,
          label: 'Username or Registered Email',
          hint: 'e.g. admin@ramastore.com or customer@ramastore.com',
          prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _loginPasswordController,
          label: 'Account Password',
          hint: '••••••••',
          obscureText: true,
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberDevice,
                  activeColor: AppColors.primaryGold,
                  onChanged: (val) => setState(() => _rememberDevice = val ?? true),
                ),
                const Text('Remember device', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _requireMfa,
                  activeColor: AppColors.secondaryFixedDim,
                  onChanged: (val) => setState(() => _requireMfa = val ?? true),
                ),
                const Text('2-Step MFA Active', style: TextStyle(color: AppColors.secondaryFixedDim, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppButton(
          text: _requireMfa ? 'Proceed to 2-Step MFA Challenge' : 'Sign In to Store',
          isLoading: authState.isLoading,
          onPressed: () async {
            final id = _loginIdentifierController.text.trim();
            final pass = _loginPasswordController.text;
            if (id.isEmpty || pass.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill in both username/email and password')),
              );
              return;
            }

            if (_requireMfa) {
              final res = await OtpService.sendOtp(id);
              _startResendTimer();
              setState(() => _mfaStepActive = true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🔐 2-Factor Authentication challenge dispatched: ${res['otp']}'),
                    backgroundColor: AppColors.surface,
                    duration: const Duration(seconds: 8),
                  ),
                );
              }
            } else {
              ref.read(authNotifierProvider.notifier).loginPassword(id, pass);
            }
          },
        ),
      ],
    );
  }

  Widget _buildOtpLoginTab(AuthState authState) {
    return Column(
      children: [
        if (!_otpSentForLogin) ...[
          AppTextField(
            controller: _otpPhoneController,
            label: 'Registered Email or Mobile Number',
            hint: 'Enter your email or phone',
            prefixIcon: const Icon(Icons.phone_android, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Send 6-Digit OTP Code',
            isLoading: authState.isLoading,
            onPressed: () async {
              final id = _otpPhoneController.text.trim();
              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter phone or email address')),
                );
                return;
              }
              final res = await OtpService.sendOtp(id);
              setState(() {
                _otpSentForLogin = true;
              });
              _startResendTimer();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.sms_rounded, color: AppColors.primaryGold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '📱 OTP code sent: ${res['otp']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 8),
                    backgroundColor: AppColors.surface,
                  ),
                );
              }
            },
          ),
        ] else ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryGold),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read, color: AppColors.primaryGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📱 OTP Sent to ${_otpPhoneController.text.trim()}',
                        style: const TextStyle(color: AppColors.primaryGoldLight, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Enter the 6-digit code sent to your device to sign in.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppTextField(
            controller: _otpCodeController,
            label: 'Enter 6-Digit OTP Code',
            hint: 'Enter OTP',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.pin, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _resendSeconds > 0
                    ? null
                    : () async {
                        final res = await OtpService.sendOtp(_otpPhoneController.text.trim());
                        _startResendTimer();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('🔄 New OTP Sent: ${res['otp']}')),
                          );
                        }
                      },
                child: Text(
                  _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend OTP Code',
                  style: TextStyle(color: _resendSeconds > 0 ? AppColors.textMuted : AppColors.primaryGoldLight),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _otpSentForLogin = false),
                child: const Text('Change Phone/Email', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Verify & Sign In',
            isLoading: authState.isLoading,
            onPressed: () {
              final code = _otpCodeController.text.trim();
              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter 6-digit OTP')),
                );
                return;
              }
              ref.read(authNotifierProvider.notifier).loginOtpVerify(_otpPhoneController.text.trim(), code);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterTab(AuthState authState) {
    return Column(
      children: [
        if (!_otpSentForReg) ...[
          AppTextField(
            controller: _regUsernameController,
            label: 'Full Name',
            hint: 'e.g. John Doe',
            prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _regEmailController,
            label: 'Email Address or Phone',
            hint: 'e.g. john@example.com',
            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _regPasswordController,
            label: 'Create Secure Password',
            hint: '••••••••',
            obscureText: true,
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Create Account & Send Verification Code',
            isLoading: authState.isLoading,
            onPressed: () async {
              final user = _regUsernameController.text.trim();
              final email = _regEmailController.text.trim();
              final pass = _regPasswordController.text;

              if (user.isEmpty || email.isEmpty || pass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please complete all registration fields')),
                );
                return;
              }
              final res = await OtpService.sendOtp(email);
              setState(() {
                _otpSentForReg = true;
              });
              _startResendTimer();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📱 Verification code dispatched: ${res['otp']}'),
                    duration: const Duration(seconds: 8),
                  ),
                );
              }
            },
          ),
        ] else ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryGold),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read, color: AppColors.primaryGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📱 Verification Code Sent to ${_regEmailController.text.trim()}',
                        style: const TextStyle(color: AppColors.primaryGoldLight, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Enter the 6-digit code sent to your email/phone to activate your account.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppTextField(
            controller: _regOtpController,
            label: 'Enter 6-Digit Verification Code',
            hint: 'Enter OTP',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.security, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _resendSeconds > 0
                    ? null
                    : () async {
                        final res = await OtpService.sendOtp(_regEmailController.text.trim());
                        _startResendTimer();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('🔄 New Code Sent: ${res['otp']}')),
                          );
                        }
                      },
                child: Text(
                  _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend Code',
                  style: TextStyle(color: _resendSeconds > 0 ? AppColors.textMuted : AppColors.primaryGoldLight),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _otpSentForReg = false),
                child: const Text('Edit Details', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Verify & Activate Account',
            isLoading: authState.isLoading,
            onPressed: () {
              final code = _regOtpController.text.trim();
              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter 6-digit code')),
                );
                return;
              }
              ref.read(authNotifierProvider.notifier).registerVerify(
                    _regEmailController.text.trim(),
                    code,
                    username: _regUsernameController.text.trim(),
                  );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildForgotPasswordTab(AuthState authState) {
    return Column(
      children: [
        if (!_otpSentForForgot) ...[
          AppTextField(
            controller: _forgotEmailController,
            label: 'Registered Email or Phone',
            hint: 'Enter your registered email or mobile',
            prefixIcon: const Icon(Icons.lock_reset, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Send Reset OTP Code',
            isLoading: authState.isLoading,
            onPressed: () async {
              final id = _forgotEmailController.text.trim();
              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email or phone')),
                );
                return;
              }
              final res = await OtpService.sendOtp(id);
              setState(() {
                _otpSentForForgot = true;
              });
              _startResendTimer();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('📱 Password Reset Code dispatched: ${res['otp']}')),
                );
              }
            },
          ),
        ] else ...[
          AppTextField(
            controller: _forgotOtpController,
            label: 'Enter 6-Digit Reset Code',
            hint: 'Enter OTP',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.pin, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _forgotNewPassController,
            label: 'Create New Password',
            hint: '••••••••',
            obscureText: true,
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Update Password & Sign In',
            isLoading: authState.isLoading,
            onPressed: () {
              final code = _forgotOtpController.text.trim();
              final newPass = _forgotNewPassController.text;
              if (code.isEmpty || newPass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter both reset code and new password')),
                );
                return;
              }
              final result = OtpService.verifyOtp(_forgotEmailController.text.trim(), code);
              if (result.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✨ Password updated successfully! Signing you in...'), backgroundColor: AppColors.success),
                );
                ref.read(authNotifierProvider.notifier).loginPassword(_forgotEmailController.text.trim(), newPass);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.error ?? 'Invalid code. Please check and try again.'), backgroundColor: AppColors.error),
                );
              }
            },
          ),
        ],
      ],
    );
  }
}
