class AppConstants {
  static const String appName = 'Rama Store';
  static const String appTagline = 'Curated Essentials for Your Daily Lifestyle';
  
  // Default Base API URL (Overrideable via --dart-define=BASE_URL=http://...)
  static const String defaultBaseUrl = 'https://rama-store-api.onrender.com';
  
  // Free delivery threshold in Indian Rupees
  static const double freeDeliveryThreshold = 500.0;
  static const double flatDeliveryFee = 49.0;
  
  // Loyalty cashback percentage
  static const double loyaltyCashbackRate = 0.10; // 10% cash-back
  
  // Debounce duration for search input
  static const int searchDebounceMs = 300;
  
  // Storage keys
  static const String keyAuthSession = 'auth_session_cookie';
  static const String keyUserEmail = 'user_email_or_phone';
  static const String keyUserFullname = 'user_fullname';
  static const String keyUserRole = 'user_role';
  static const String keyCartData = 'local_cart_json';
  static const String keyLoyaltyBalance = 'local_loyalty_balance';
  static const String keyCachedProducts = 'cached_products_json';
  static const String keyCachedOrders = 'cached_orders_json';
}
