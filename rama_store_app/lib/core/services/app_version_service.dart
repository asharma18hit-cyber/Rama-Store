import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

enum VersionStatus { upToDate, optionalUpdate, mandatoryUpdate }

class AppVersionService {
  static const String currentAppVersion = '3.5.0';
  static const String minSupportedVersion = '3.0.0';
  static const String latestAvailableVersion = '3.5.0';
  static const String downloadUrl = '/downloads/rama-store-app.apk';

  /// Check version compatibility
  static VersionStatus checkVersionStatus({
    String current = currentAppVersion,
    String minimum = minSupportedVersion,
    String latest = latestAvailableVersion,
  }) {
    if (_isVersionBelow(current, minimum)) {
      return VersionStatus.mandatoryUpdate;
    }
    if (_isVersionBelow(current, latest)) {
      return VersionStatus.optionalUpdate;
    }
    return VersionStatus.upToDate;
  }

  static bool _isVersionBelow(String versionA, String versionB) {
    try {
      final partsA = versionA.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final partsB = versionB.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final a = i < partsA.length ? partsA[i] : 0;
        final b = i < partsB.length ? partsB[i] : 0;
        if (a < b) return true;
        if (a > b) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Display Update Modal Prompt if needed
  static void showUpdatePromptIfNeeded(BuildContext context, {bool force = false}) {
    final status = checkVersionStatus();
    if (status == VersionStatus.upToDate && !force) return;

    final isMandatory = status == VersionStatus.mandatoryUpdate;

    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => !isMandatory,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixedDim.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.system_update_rounded, color: AppColors.secondaryFixedDim, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  isMandatory ? 'Update Required' : 'New Version Available',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMandatory
                      ? 'This installed version of Rama Store ($currentAppVersion) is no longer supported. Please update to continue using the application.'
                      : 'A new version ($latestAvailableVersion) of Rama Store is available with live synchronization, instant image upload, and performance enhancements.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Current Version:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('v$currentAppVersion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!isMandatory)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryFixedDim,
                  foregroundColor: const Color(0xFF005236),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Update App Now', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                  if (!isMandatory && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
