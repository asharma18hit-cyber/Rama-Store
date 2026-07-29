import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../main.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;
  final String location;

  const MainScaffold({
    Key? key,
    required this.child,
    required this.location,
  }) : super(key: key);

  int _calculateSelectedIndex(BuildContext context) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/catalog')) return 1;
    if (location.startsWith('/cart')) return 2;
    if (location.startsWith('/orders')) return 3;
    if (location.startsWith('/profile') || location.startsWith('/loyalty')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/catalog');
        break;
      case 2:
        context.go('/cart');
        break;
      case 3:
        context.go('/orders');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartNotifierProvider);
    final itemCount = cartState.totalItemCount;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.surfaceLight, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _calculateSelectedIndex(context),
          onTap: (index) => _onItemTapped(index, context),
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.primaryGoldLight,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Store',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Catalog',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                label: Text(itemCount.toString()),
                isLabelVisible: itemCount > 0,
                backgroundColor: AppColors.primaryGold,
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              activeIcon: Badge(
                label: Text(itemCount.toString()),
                isLabelVisible: itemCount > 0,
                backgroundColor: AppColors.primaryGold,
                child: const Icon(Icons.shopping_bag_rounded),
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
