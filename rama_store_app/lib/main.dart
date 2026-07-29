import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/storage/local_storage_service.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'features/auth/presentation/auth_screen.dart';

import 'features/catalog/data/catalog_repository.dart';
import 'features/catalog/data/catalog_models.dart';
import 'features/catalog/presentation/catalog_notifier.dart';
import 'features/catalog/presentation/home_screen.dart';
import 'features/catalog/presentation/catalog_screen.dart';
import 'features/catalog/presentation/product_detail_screen.dart';

import 'features/cart/data/cart_repository.dart';
import 'features/cart/presentation/cart_notifier.dart';
import 'features/cart/presentation/cart_screen.dart';

import 'features/checkout/data/checkout_repository.dart';
import 'features/checkout/presentation/checkout_screen.dart';

import 'features/orders/data/orders_repository.dart';
import 'features/orders/presentation/orders_screen.dart';

import 'features/loyalty/data/loyalty_repository.dart';
import 'features/loyalty/presentation/loyalty_screen.dart';

import 'features/profile/presentation/profile_screen.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'shared/layouts/main_scaffold.dart';

import 'features/catalog/presentation/wishlist_notifier.dart';
import 'features/catalog/presentation/wishlist_screen.dart';
import 'features/profile/data/address_repository.dart';

// Top-Level Dependency Providers
late final LocalStorageService _storageService;

final localStorageProvider = Provider<LocalStorageService>((ref) => _storageService);

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ApiClient(storage: storage);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageProvider);
  return ApiAuthRepository(apiClient: apiClient, storage: storage);
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageProvider);
  return ApiCatalogRepository(apiClient: apiClient, storage: storage);
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return CartRepository(storage);
});

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiCheckoutRepository(apiClient: apiClient);
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiOrdersRepository(apiClient: apiClient);
});

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return LoyaltyRepository(storage);
});

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return AddressRepository(storage);
});

// State Notifier Providers
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});

final catalogNotifierProvider = StateNotifierProvider<CatalogNotifier, CatalogState>((ref) {
  final repo = ref.watch(catalogRepositoryProvider);
  return CatalogNotifier(repo);
});

final cartNotifierProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final repo = ref.watch(cartRepositoryProvider);
  return CartNotifier(repo);
});

final wishlistNotifierProvider = StateNotifierProvider<WishlistNotifier, List<int>>((ref) {
  final storage = ref.watch(localStorageProvider);
  return WishlistNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorageService storage;
  static const _keyTheme = 'app_theme_mode';

  ThemeModeNotifier(this.storage)
      : super(storage.getBool(_keyTheme) == false ? ThemeMode.light : ThemeMode.dark);

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      storage.setBool(_keyTheme, false);
    } else {
      state = ThemeMode.dark;
      storage.setBool(_keyTheme, true);
    }
  }
}

final themeModeNotifierProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ThemeModeNotifier(storage);
});

// GoRouter Navigation Config with Deep-Linking
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final tabIndexStr = state.uri.queryParameters['tab'];
          final tabIndex = tabIndexStr != null ? int.tryParse(tabIndexStr) ?? 0 : 0;
          return AuthScreen(initialTabIndex: tabIndex);
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(
            location: state.uri.toString(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const CatalogScreen(),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final productIdStr = state.pathParameters['id'];
          final extraProduct = state.extra as Product?;
          final product = extraProduct ??
              Product(
                id: int.tryParse(productIdStr ?? '1') ?? 1,
                sku: 'RAMA-PROD',
                name: 'Rama Store Retail Item',
                sellingPrice: 499.0,
                stock: 10,
                status: 'published',
              );
          return ProductDetailScreen(product: product);
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/loyalty',
        builder: (context, state) => const LoyaltyScreen(),
      ),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistScreen(),
      ),
    ],
  );
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage initialization
  _storageService = await LocalStorageService.init();

  // Non-critical services lazy initialization
  NotificationService.initialize();

  runApp(
    const ProviderScope(
      child: RamaStoreApp(),
    ),
  );
}

class RamaStoreApp extends ConsumerWidget {
  const RamaStoreApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeNotifierProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
