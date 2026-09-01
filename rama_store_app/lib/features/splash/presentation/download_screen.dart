import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_downloader.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/frosted_glass_container.dart';
import '../../../shared/widgets/hover_card.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Download Rama Store Mobile App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: FrostedGlassContainer(
              padding: const EdgeInsets.all(32),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixedDim,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondaryFixedDim.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.phone_android_rounded, size: 44, color: Color(0xFF005236)),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'RAMA STORE MOBILE',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.secondaryFixedDim),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Android APK Official Release',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Experience instant 1-click checkout, live delivery stepper, and 10% loyalty rewards.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 24),

                  // Metadata Cards
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildInfoBadge(Icons.verified_outlined, 'Version', 'v3.0.0 (Release)'),
                      _buildInfoBadge(Icons.data_usage_rounded, 'Package Size', '53.4 MB'),
                      _buildInfoBadge(Icons.android_rounded, 'Compatibility', 'Android 8.0+'),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // QR Code
                  HoverCard(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 160,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan with phone camera to download directly to your smartphone',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),

                  // 1-Click Direct Download CTA Button
                  AppButton(
                    text: 'Download Android APK (53.4 MB)',
                    icon: Icons.download_rounded,
                    onPressed: () {
                      downloadFileFromUrl('/downloads/rama-store-app.apk', filename: 'rama-store-app.apk');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.download_done_rounded, color: AppColors.secondaryFixedDim),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text('🚀 Download started! Check your device downloads for rama-store-app.apk'),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.surface,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Step-by-Step Installation Guide
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('📋 3-Step Installation Guide:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        SizedBox(height: 10),
                        Text('1. Tap the "Download Android APK" button above.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        Text('2. Open the downloaded rama-store-app.apk file from your notification bar or Files app.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        Text('3. When prompted, enable "Install unknown apps" in Settings and tap "Install".', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextButton.icon(
                    icon: const Icon(Icons.storefront_rounded, size: 16, color: AppColors.secondaryFixedDim),
                    label: const Text('Back to Web Storefront', style: TextStyle(color: AppColors.secondaryFixedDim, fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.secondaryFixedDim),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
