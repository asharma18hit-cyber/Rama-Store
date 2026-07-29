import 'package:flutter/material.dart';

class NotificationService {
  static Future<void> initialize() async {
    // FCM initialization wrapper for order status & loyalty alerts
    debugPrint('[FCM] Push Notification Service initialized');
  }

  static void showOrderNotification(String orderId, String status) {
    debugPrint('[FCM Notification] Order #$orderId status updated to $status');
  }

  static void showLoyaltyAlert(double pointsEarned) {
    debugPrint('[FCM Notification] Congratulations! You earned ${pointsEarned.toStringAsFixed(0)} loyalty points');
  }
}
