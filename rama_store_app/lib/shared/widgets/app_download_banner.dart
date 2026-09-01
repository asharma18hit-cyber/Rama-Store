import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/file_downloader.dart';
import 'frosted_glass_container.dart';

class AppDownloadBanner extends StatefulWidget {
  const AppDownloadBanner({super.key});

  @override
  State<AppDownloadBanner> createState() => _AppDownloadBannerState();
}

class _AppDownloadBannerState extends State<AppDownloadBanner> {
  bool _dismissed = false;

  void _showQrCodeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: FrostedGlassContainer(
          padding: const EdgeInsets.all(24),
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📱 Get Rama Store App',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 180,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan QR code with your phone camera to download the Android APK & enjoy instant checkout!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                label: const Text('Download APK Directly (53 MB)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  downloadFileFromUrl('/downloads/rama-store-app.apk', filename: 'rama-store-app.apk');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.download_done_rounded, color: AppColors.secondaryFixedDim),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('🚀 Download started! Check your browser downloads for rama-store-app.apk'),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.surface,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only display on web platforms
    if (!kIsWeb || _dismissed) return const SizedBox.shrink();

    final isSmallScreen = MediaQuery.of(context).size.width < 700;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3525CD).withValues(alpha: 0.95),
            const Color(0xFF1E1B4B).withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3525CD).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.secondaryFixedDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_android_rounded, size: 20, color: Color(0xFF005236)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '📱 Get the Rama Store Mobile App',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                if (!isSmallScreen)
                  const Text(
                    'Faster 1-click checkout, instant push order tracking, and 10% loyalty cashback!',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.secondaryFixedDim, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.secondaryFixedDim),
            label: Text(isSmallScreen ? 'Get App' : 'Download APK / Scan QR', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => _showQrCodeModal(context),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}
