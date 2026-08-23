import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOffline;

  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.wifi_off_rounded, size: 16, color: Colors.black87),
          SizedBox(width: 8),
          Text(
            'Offline Mode — Browsing cached store catalog',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
