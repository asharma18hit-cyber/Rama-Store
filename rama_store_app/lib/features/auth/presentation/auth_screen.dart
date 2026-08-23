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
  bool _otpSentForLogin = false;
  bool _otpSentForReg = false;
  bool _otpSentForForgot = false;
  String? _lastGeneratedOtp;
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
        title: const Text('Rama Store Auth'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGold,
          labelColor: AppColors.primaryGoldLight,
          unselectedLabelColor: AppColors.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Password Login'),
            Tab(text: 'OTP Login'),
            Tab(text: 'Sign Up'),
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
                  const Icon(Icons.shield_outlined, color: AppColors.primaryGoldLight, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Rama Store Direct Account Access',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Same account & loyalty points balance across mobile app and website',
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
              height: 480,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPasswordLoginTab(authState),
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

  Widget _buildPasswordLoginTab(AuthState authState) {
    return Column(
      children: [
        AppTextField(
          controller: _loginIdentifierController,
          label: 'Username or Registered Email',
          hint: 'e.g. johndoe or john@example.com',
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
          children: [
            Checkbox(
              value: _rememberDevice,
              activeColor: AppColors.primaryGold,
              onChanged: (val) => setState(() => _rememberDevice = val ?? true),
            ),
            const Text('Remember device', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 24),
        AppButton(
          text: 'Sign In to Store',
          isLoading: authState.isLoading,
          onPressed: () {
            final id = _loginIdentifierController.text.trim();
            final pass = _loginPasswordController.text;
            if (id.isEmpty || pass.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill in both fields')),
              );
              return;
            }
            ref.read(authNotifierProvider.notifier).loginPassword(id, pass);
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
              final otpRes = await OtpService.sendOtp(id);
              setState(() {
                _otpSentForLogin = true;
                _lastGeneratedOtp = otpRes['otp'] as String?;
              });
              _startResendTimer();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.sms_rounded, color: AppColors.primaryGold),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '📱 OTP Request dispatched. Enter code or use sandbox 123456.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    duration: Duration(seconds: 5),
                    backgroundColor: AppColors.surface,
                  ),
                );
              }
              ref.read(authNotifierProvider.notifier).loginOtpRequest(id);
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
                        'Didn\'t receive SMS? Enter sandbox code 123456 or tap Resend OTP below.',
                        style: TextStyle(color: AppColors.accentAmber, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppTextField(
            controller: _otpCodeController,
            label: '6-Digit Verification Code',
            hint: 'Enter 6-digit OTP (e.g. 123456)',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.pin, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          AppButton(
            text: 'Verify Code & Sign In',
            isLoading: authState.isLoading,
            onPressed: () {
              final code = _otpCodeController.text.trim();
              if (code.isEmpty) return;
              final isValid = OtpService.verifyOtp(_otpPhoneController.text, code);
              if (isValid) {
                ref.read(authNotifierProvider.notifier).loginOtpVerify(code);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid code. Try entering 123456 to verify.'), backgroundColor: AppColors.error),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _otpSentForLogin = false),
                child: const Text('Change Phone Number', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(
                  _resendSeconds > 0 ? 'Resend OTP (${_resendSeconds}s)' : 'Resend OTP Code Now',
                  style: TextStyle(
                    color: _resendSeconds > 0 ? AppColors.textMuted : AppColors.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                onPressed: _resendSeconds > 0
                    ? null
                    : () async {
                        final id = _otpPhoneController.text.trim();
                        if (id.isEmpty) return;
                        final otpRes = await OtpService.sendOtp(id);
                        setState(() => _lastGeneratedOtp = otpRes['otp'] as String?);
                        _startResendTimer();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('New 6-digit OTP dispatched to your number!')),
                          );
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _otpSentForLogin = false),
            child: const Text('Change Email / Phone', style: TextStyle(color: AppColors.primaryGold)),
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterTab(AuthState authState) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (!_otpSentForReg) ...[
            AppTextField(
              controller: _regUsernameController,
              label: 'Full Name / Username',
              hint: 'e.g. John Doe',
              prefixIcon: const Icon(Icons.person, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _regEmailController,
              label: 'Email or Mobile Number',
              hint: 'john@example.com',
              prefixIcon: const Icon(Icons.email, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _regPasswordController,
              label: 'Create Password',
              hint: 'At least 6 characters',
              obscureText: true,
              prefixIcon: const Icon(Icons.lock, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            AppButton(
              text: 'Register Account & Get OTP',
              isLoading: authState.isLoading,
              onPressed: () async {
                final uname = _regUsernameController.text.trim();
                final email = _regEmailController.text.trim();
                final pass = _regPasswordController.text;
                if (uname.isEmpty || email.isEmpty) return;
                final ok = await ref.read(authNotifierProvider.notifier).registerRequest(uname, email, pass);
                if (ok) setState(() => _otpSentForReg = true);
              },
            ),
          ] else ...[
            AppTextField(
              controller: _regOtpController,
              label: 'Enter Registration Verification Code',
              hint: '6-digit OTP',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            AppButton(
              text: 'Complete Signup',
              isLoading: authState.isLoading,
              onPressed: () {
                final otp = _regOtpController.text.trim();
                if (otp.isEmpty) return;
                ref.read(authNotifierProvider.notifier).registerVerify(otp);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForgotPasswordTab(AuthState authState) {
    return Column(
      children: [
        if (!_otpSentForForgot) ...[
          AppTextField(
            controller: _forgotEmailController,
            label: 'Registered Email or Phone',
            hint: 'Enter your account email',
            prefixIcon: const Icon(Icons.mail_outline, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Request Reset Code',
            isLoading: authState.isLoading,
            onPressed: () async {
              final id = _forgotEmailController.text.trim();
              if (id.isEmpty) return;
              final ok = await ref.read(authNotifierProvider.notifier).forgotPasswordRequest(id);
              if (ok) setState(() => _otpSentForForgot = true);
            },
          ),
        ] else ...[
          AppTextField(
            controller: _forgotOtpController,
            label: '6-Digit Reset Code',
            hint: 'OTP code',
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _forgotNewPassController,
            label: 'New Password',
            hint: 'At least 6 characters',
            obscureText: true,
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Save New Password & Sign In',
            isLoading: authState.isLoading,
            onPressed: () async {
              final email = _forgotEmailController.text.trim();
              final otp = _forgotOtpController.text.trim();
              final pass = _forgotNewPassController.text;
              if (otp.isEmpty || pass.isEmpty) return;
              final ok = await ref.read(authNotifierProvider.notifier).resetPassword(email, otp, pass);
              if (ok) {
                _tabController.animateTo(0);
                setState(() => _otpSentForForgot = false);
              }
            },
          ),
        ],
      ],
    );
  }
}
