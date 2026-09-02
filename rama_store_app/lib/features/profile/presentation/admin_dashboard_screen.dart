import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/frosted_glass_container.dart';
import '../../../shared/widgets/hover_card.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/presentation/catalog_notifier.dart';
import '../../orders/data/order_model.dart';
import '../../orders/presentation/orders_screen.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../shared/widgets/product_image_view.dart';
import '../../admin/data/store_config_model.dart';
import '../../admin/presentation/store_config_notifier.dart';
import '../../../main.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatusFilter = 'all';
  String? _selectedCategoryFilter;

  final List<Map<String, String>> _auditLogs = [
    {'action': 'Store Policy Synchronized', 'detail': 'Free delivery threshold set to ₹500', 'time': '1 min ago'},
    {'action': 'MFA Session Verified', 'detail': 'Admin authentication successful', 'time': '2 mins ago'},
    {'action': 'Catalog In-Sync', 'detail': 'Live product catalog loaded with real-time state', 'time': '5 mins ago'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addAuditLog(String action, String detail) {
    setState(() {
      _auditLogs.insert(0, {
        'action': action,
        'detail': detail,
        'time': 'Just now',
      });
    });
  }

  void _showPublishProductDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PublishProductSheet(
        onPublished: (title) {
          _addAuditLog('Product Published', title);
        },
      ),
    );
  }

  void _showCreateCategoryDialog() {
    final nameController = TextEditingController();
    final slugController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Store Category', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: nameController,
              label: 'Category Name',
              hint: 'e.g. Gourmet Spices',
              onChanged: (val) => slugController.text = val.toLowerCase().replaceAll(' ', '-'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: slugController,
              label: 'Category Slug',
              hint: 'gourmet-spices',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryFixedDim,
              foregroundColor: const Color(0xFF005236),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              final slug = slugController.text.trim();
              if (name.isNotEmpty) {
                final newCat = Category(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  name: name,
                );
                ref.read(catalogNotifierProvider.notifier).addCategory(newCat);
                _addAuditLog('Category Created', 'Added new category "$name"');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✨ Category "$name" created successfully!')),
                );
              }
            },
            child: const Text('Create Category'),
          ),
        ],
      ),
    );
  }

  void _showEditPriceStockDialog(Product product) {
    final priceController = TextEditingController(text: product.sellingPrice.toStringAsFixed(0));
    final stockController = TextEditingController(text: product.stock.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.secondaryFixedDim),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Edit "${product.name}"', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Instant Price & Stock Real-Time Sync', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            AppTextField(
              controller: priceController,
              label: 'Selling Price (₹)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: stockController,
              label: 'Available Stock Units',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryFixedDim,
              foregroundColor: const Color(0xFF005236),
            ),
            onPressed: () {
              final newPrice = double.tryParse(priceController.text.trim()) ?? product.sellingPrice;
              final newStock = int.tryParse(stockController.text.trim()) ?? product.stock;

              ref.read(catalogNotifierProvider.notifier).updateProductPriceAndStock(
                product.id,
                sellingPrice: newPrice,
                stock: newStock,
              );

              _addAuditLog('Price/Stock Updated', 'Updated "${product.name}" price to ₹$newPrice and stock to $newStock');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✨ "${product.name}" updated live to ₹$newPrice (Stock: $newStock)!')),
              );
            },
            child: const Text('Save & Broadcast Live'),
          ),
        ],
      ),
    );
  }

  void _showDeleteProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Product', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${product.name}" (SKU: ${product.sku}) from the store catalog?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(catalogNotifierProvider.notifier).deleteProduct(product.id);
              _addAuditLog('Product Deleted', 'Permanently removed "${product.name}"');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🗑️ Product "${product.name}" removed from store')),
              );
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isAdmin = authState.isAuthenticated &&
        (authState.user?.role == 'admin' || authState.user?.role == 'super_admin');

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FrostedGlassContainer(
              padding: const EdgeInsets.all(32),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, size: 48, color: AppColors.error),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '403 Forbidden Access',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You must be signed in with an Administrator account to view this portal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Authenticate as Admin',
                    icon: Icons.login_rounded,
                    onPressed: () => context.go('/admin/login'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.storefront_rounded, size: 16, color: AppColors.textSecondary),
                    label: const Text('Back to Storefront', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final catalogState = ref.watch(catalogNotifierProvider);
    final storeConfig = ref.watch(storeConfigProvider);
    final ordersAsync = ref.watch(ordersFutureProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondaryFixedDim,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ADMIN CONSOLE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF005236), letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Rama Store Master Center', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.secondaryFixedDim),
            tooltip: 'Publish Product',
            onPressed: _showPublishProductDialog,
          ),
          IconButton(
            icon: const Icon(Icons.storefront_rounded),
            tooltip: 'View Live Storefront',
            onPressed: () => context.go('/home'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Logout Admin',
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
              context.go('/home');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isDesktop,
          indicatorColor: AppColors.secondaryFixedDim,
          labelColor: AppColors.secondaryFixedDim,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
            Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Products & Prices'),
            Tab(icon: Icon(Icons.category_rounded), text: 'Categories'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Delivery & Offers'),
            Tab(icon: Icon(Icons.shopping_cart_checkout_rounded), text: 'Orders OMS'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Audit Trail'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Real-Time Metrics & Overview
          _buildDashboardTab(catalogState, ordersAsync),

          // 2. Products Management & Live Price Editor
          _buildProductsTab(catalogState),

          // 3. Category Manager
          _buildCategoriesTab(catalogState),

          // 4. Store Policy, Delivery & Coupons Control
          _buildStoreConfigTab(storeConfig),

          // 5. Orders OMS Management
          _buildOrdersTab(),

          // 6. Audit Trail Logs
          _buildAuditLogsTab(),
        ],
      ),
    );
  }

  // TAB 1: METRICS DASHBOARD (100% Real-Time Live Computed)
  Widget _buildDashboardTab(CatalogState catalogState, AsyncValue<List<OrderModel>> ordersAsync) {
    final orders = ordersAsync.valueOrNull ?? [];
    final publishedCount = catalogState.products.where((p) => p.status == 'published').length;
    final draftCount = catalogState.products.where((p) => p.status != 'published').length;
    final lowStockCount = catalogState.products.where((p) => p.stock <= 5).length;

    final totalRevenue = orders.fold(0.0, (sum, o) => sum + (o.orderStatus != 'Cancelled' ? o.totalAmount : 0.0));
    final activeOrders = orders.where((o) => o.orderStatus != 'Delivered' && o.orderStatus != 'Cancelled').length;
    final deliveredOrders = orders.where((o) => o.orderStatus == 'Delivered').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Real-Time Store Metrics', style: Theme.of(context).textTheme.headlineMedium),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixedDim.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondaryFixedDim),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.circle, size: 8, color: AppColors.secondaryFixedDim),
                    SizedBox(width: 6),
                    Text('LIVE SYNC ACTIVE', style: TextStyle(color: AppColors.secondaryFixedDim, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Metrics Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard(
                'Live Store Revenue',
                Formatters.formatCurrency(totalRevenue),
                '${orders.length} Total Orders Placed',
                Icons.currency_rupee,
                AppColors.secondaryFixedDim,
                true,
              ),
              _buildMetricCard(
                'Active Fulfillment Orders',
                '$activeOrders Orders',
                '$deliveredOrders Delivered to Date',
                Icons.shopping_bag_outlined,
                AppColors.primaryFixedDim,
                false,
              ),
              _buildMetricCard(
                'Published Live Items',
                '$publishedCount Products',
                '$draftCount in draft/unpublished',
                Icons.inventory_2_outlined,
                AppColors.primaryGoldLight,
                false,
              ),
              _buildMetricCard(
                'Low Stock Alerts',
                '$lowStockCount Items',
                lowStockCount > 0 ? 'Action Required (≤5 units)' : 'Healthy Inventory',
                Icons.warning_amber_rounded,
                lowStockCount > 0 ? AppColors.error : AppColors.secondaryFixedDim,
                false,
              ),
            ],
          ),

          const SizedBox(height: 28),
          Text('Catalog Quick Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Publish New Product Listing',
                  icon: Icons.add_circle_outline,
                  onPressed: _showPublishProductDialog,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                  text: 'Create New Store Category',
                  icon: Icons.create_new_folder_outlined,
                  isOutlined: true,
                  onPressed: _showCreateCategoryDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String sub, IconData icon, Color color, bool isGold) {
    return HoverCard(
      child: FrostedGlassContainer(
        padding: const EdgeInsets.all(20),
        width: 250,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // TAB 2: PRODUCTS & PUBLISHING WITH LIVE PRICE EDITOR
  Widget _buildProductsTab(CatalogState catalogState) {
    var filtered = catalogState.products;
    if (_selectedStatusFilter != 'all') {
      filtered = filtered.where((p) => p.status == _selectedStatusFilter).toList();
    }
    if (_selectedCategoryFilter != null) {
      filtered = filtered.where((p) => p.categoryName == _selectedCategoryFilter).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Products Management & Real-Time Price Editor (${filtered.length})', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryFixedDim,
                  foregroundColor: const Color(0xFF005236),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _showPublishProductDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Row
          Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Published', 'published'),
              const SizedBox(width: 8),
              _buildFilterChip('Drafts', 'draft'),
            ],
          ),
          const SizedBox(height: 16),

          // Product Table List
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No products match criteria', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      final isPublished = product.status == 'published';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          children: [
                            ProductImageView(
                              imageUrl: product.imageUrl,
                              width: 52,
                              height: 52,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPublished
                                              ? AppColors.secondaryFixedDim.withValues(alpha: 0.2)
                                              : AppColors.accentAmber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isPublished ? 'LIVE' : 'DRAFT',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isPublished ? AppColors.secondaryFixedDim : AppColors.accentAmber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        Formatters.formatCurrency(product.sellingPrice),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGoldLight, fontSize: 13),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Stock: ${product.stock} units',
                                        style: TextStyle(
                                          color: product.stock <= 5 ? AppColors.error : AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: product.stock <= 5 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(product.categoryName ?? 'General', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit Price & Stock', style: TextStyle(fontSize: 11)),
                              onPressed: () => _showEditPriceStockDialog(product),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isPublished,
                              activeColor: AppColors.secondaryFixedDim,
                              onChanged: (val) {
                                final newStatus = val ? 'published' : 'draft';
                                ref.read(catalogNotifierProvider.notifier).updateProductStatus(product.id, newStatus);
                                _addAuditLog('Status Changed', 'Changed "${product.name}" to $newStatus');
                              },
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              tooltip: 'Delete Product',
                              onPressed: () => _showDeleteProductDialog(product),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.secondaryFixedDim,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF005236) : AppColors.textSecondary,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedStatusFilter = value);
      },
    );
  }

  // TAB 3: CATEGORIES MANAGER
  Widget _buildCategoriesTab(CatalogState catalogState) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Store Categories (${catalogState.categories.length})', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryFixedDim,
                  foregroundColor: const Color(0xFF005236),
                ),
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _showCreateCategoryDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: catalogState.categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cat = catalogState.categories[index];
                final productCount = catalogState.products.where((p) => p.categoryId == cat.id || p.categoryName == cat.name).length;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined, color: AppColors.secondaryFixedDim),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('$productCount active products in department', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: STORE POLICY, DELIVERY CHARGES & PROMO COUPONS CONTROL CENTER
  Widget _buildStoreConfigTab(StoreConfig storeConfig) {
    final thresholdController = TextEditingController(text: storeConfig.freeDeliveryThreshold.toStringAsFixed(0));
    final feeController = TextEditingController(text: storeConfig.standardDeliveryFee.toStringAsFixed(0));
    final announcementController = TextEditingController(text: storeConfig.announcementText);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('⚙️ Real-Time Store Policy & Offers Controller', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Changes immediately broadcast to customer carts, checkout, and storefront', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Delivery Charges Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondaryFixedDim.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.local_shipping_outlined, color: AppColors.secondaryFixedDim),
                    SizedBox(width: 10),
                    Text('Delivery Charge & Free Shipping Threshold', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: thresholdController,
                        label: 'Free Delivery Order Minimum (₹)',
                        hint: '500',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        controller: feeController,
                        label: 'Standard Delivery Fee (₹)',
                        hint: '40',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Save Delivery Policy & Sync Storefront',
                  icon: Icons.sync,
                  onPressed: () {
                    final threshold = double.tryParse(thresholdController.text.trim()) ?? 500.0;
                    final fee = double.tryParse(feeController.text.trim()) ?? 40.0;

                    ref.read(storeConfigProvider.notifier).updateDeliverySettings(
                      freeThreshold: threshold,
                      standardFee: fee,
                    );
                    ref.read(cartNotifierProvider.notifier).updateDeliveryConfig(
                      threshold: threshold,
                      fee: fee,
                    );

                    _addAuditLog('Delivery Policy Updated', 'Free shipping above ₹$threshold, Flat fee ₹$fee');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✨ Delivery Policy Synced: Free above ₹$threshold | Flat ₹$fee')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Storewide Announcement Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.campaign_outlined, color: AppColors.primaryGoldLight),
                    SizedBox(width: 10),
                    Text('Storewide Live Announcement & Banner', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: announcementController,
                  label: 'Storefront Broadcast Text',
                  hint: '✨ Festive Offer: Free Delivery on orders above ₹500...',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Broadcast Announcement Live',
                  icon: Icons.broadcast_on_personal_rounded,
                  onPressed: () {
                    final text = announcementController.text.trim();
                    ref.read(storeConfigProvider.notifier).updateAnnouncement(text);
                    _addAuditLog('Announcement Broadcast', text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✨ New announcement broadcasted to storefront!')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Coupons & Promo Code Manager
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Coupons & Promo Codes (${storeConfig.coupons.length})', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryFixedDim,
                  foregroundColor: const Color(0xFF005236),
                ),
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Add Coupon Code', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showAddCouponDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: storeConfig.coupons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final coupon = storeConfig.coupons[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: coupon.isActive ? AppColors.secondaryFixedDim.withValues(alpha: 0.3) : AppColors.surfaceLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primaryGoldLight),
                      ),
                      child: Text(
                        coupon.code,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGoldLight, letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(coupon.description, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
                          Text(
                            coupon.discountType == 'percent'
                                ? '${coupon.discountValue.toStringAsFixed(0)}% OFF (Min Order: ₹${coupon.minOrderAmount.toStringAsFixed(0)})'
                                : '₹${coupon.discountValue.toStringAsFixed(0)} Flat OFF (Min Order: ₹${coupon.minOrderAmount.toStringAsFixed(0)})',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        coupon.isActive ? Icons.toggle_on : Icons.toggle_off,
                        color: coupon.isActive ? AppColors.secondaryFixedDim : AppColors.textMuted,
                        size: 32,
                      ),
                      onPressed: () {
                        ref.read(storeConfigProvider.notifier).toggleCouponStatus(coupon.code);
                        _addAuditLog('Coupon Toggled', 'Toggled ${coupon.code} state');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () {
                        ref.read(storeConfigProvider.notifier).removeCoupon(coupon.code);
                        _addAuditLog('Coupon Deleted', 'Removed coupon ${coupon.code}');
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddCouponDialog() {
    final codeController = TextEditingController();
    final descController = TextEditingController();
    final valueController = TextEditingController(text: '50');
    final minController = TextEditingController(text: '299');
    String discountType = 'flat';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161F30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Promotional Coupon', style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: codeController,
                  label: 'Coupon Code',
                  hint: 'e.g. MEGA100',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: descController,
                  label: 'Coupon Description',
                  hint: 'e.g. ₹100 Flat Discount on Weekend Orders',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Flat ₹ Off')),
                        selected: discountType == 'flat',
                        selectedColor: AppColors.secondaryFixedDim,
                        onSelected: (val) => setDialogState(() => discountType = 'flat'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('% Percentage')),
                        selected: discountType == 'percent',
                        selectedColor: AppColors.secondaryFixedDim,
                        onSelected: (val) => setDialogState(() => discountType = 'percent'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: valueController,
                        label: discountType == 'percent' ? 'Discount %' : 'Discount ₹',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: minController,
                        label: 'Min Order (₹)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryFixedDim,
                foregroundColor: const Color(0xFF005236),
              ),
              onPressed: () {
                final code = codeController.text.trim().toUpperCase();
                final desc = descController.text.trim();
                final val = double.tryParse(valueController.text.trim()) ?? 0.0;
                final min = double.tryParse(minController.text.trim()) ?? 0.0;

                if (code.isNotEmpty && val > 0) {
                  final newCoupon = StoreCoupon(
                    code: code,
                    description: desc.isNotEmpty ? desc : '$code Promo Offer',
                    discountType: discountType,
                    discountValue: val,
                    minOrderAmount: min,
                    isActive: true,
                  );
                  ref.read(storeConfigProvider.notifier).addCoupon(newCoupon);
                  _addAuditLog('Coupon Created', 'Added new coupon $code');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✨ Coupon $code created and active live!')),
                  );
                }
              },
              child: const Text('Create Coupon'),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 5: ORDERS MANAGEMENT
  Widget _buildOrdersTab() {
    final ordersAsync = ref.watch(ordersFutureProvider);

    return ordersAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: ProductCardShimmer()),
      error: (e, _) => Center(child: Text('Error loading orders: $e', style: const TextStyle(color: AppColors.error))),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(child: Text('No orders found', style: TextStyle(color: AppColors.textSecondary)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            final isCod = order.isCod;
            final isCancelled = order.orderStatus == 'Cancelled';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCancelled ? AppColors.error.withValues(alpha: 0.3) : AppColors.surfaceLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tracking: ${order.trackingNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryGoldLight),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: order.orderStatus == 'Confirmed'
                                  ? AppColors.primaryGold.withValues(alpha: 0.2)
                                  : order.orderStatus == 'Delivered'
                                      ? AppColors.secondaryFixedDim.withValues(alpha: 0.2)
                                      : isCancelled
                                          ? AppColors.error.withValues(alpha: 0.2)
                                          : AppColors.primaryFixedDim.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.orderStatus.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCancelled ? AppColors.error : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: order.isPaid
                                  ? AppColors.secondaryFixedDim.withValues(alpha: 0.2)
                                  : AppColors.accentAmber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${order.paymentMethod.toUpperCase()}: ${order.paymentStatus.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: order.isPaid ? AppColors.secondaryFixedDim : AppColors.accentAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    'Order Total: ${Formatters.formatCurrency(order.totalAmount)}  •  ${order.items.length} Items',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
                  ),
                  if (order.amountDue > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Amount Due on Delivery: ${Formatters.formatCurrency(order.amountDue)}',
                      style: const TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                  if (order.cancellationReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Cancellation Reason: ${order.cancellationReason}${order.cancellationReasonDetail != null ? " (${order.cancellationReasonDetail})" : ""}',
                      style: const TextStyle(color: AppColors.error, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isCod && !order.isPaid && !isCancelled)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryFixedDim,
                            foregroundColor: const Color(0xFF005236),
                          ),
                          icon: const Icon(Icons.payments_rounded, size: 14),
                          label: const Text('Collect COD Payment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await ref.read(ordersRepositoryProvider).adminCollectCodPayment(order.trackingNumber);
                            ref.refresh(ordersFutureProvider);
                            _addAuditLog('COD Collected', 'Marked COD order ${order.trackingNumber} as Paid');
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 6: AUDIT LOGS
  Widget _buildAuditLogsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Audit Trail & History', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _auditLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = _auditLogs[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixedDim.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.security, size: 16, color: AppColors.secondaryFixedDim),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log['action']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                            Text(log['detail']!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(log['time']!, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishProductSheet extends ConsumerStatefulWidget {
  final ValueChanged<String>? onPublished;
  const _PublishProductSheet({this.onPublished});

  @override
  ConsumerState<_PublishProductSheet> createState() => _PublishProductSheetState();
}

class _PublishProductSheetState extends ConsumerState<_PublishProductSheet> {
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _sellingPriceController = TextEditingController(text: '499');
  final _purchasePriceController = TextEditingController(text: '299');
  final _stockController = TextEditingController(text: '20');
  final _imageUrlController = TextEditingController(text: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600');

  String _selectedCategory = 'Books';
  int _selectedCategoryId = 4;
  String _publicationStatus = 'published';

  final Map<String, int> _categories = {
    'Books': 4,
    'Bakery': 1,
    'Groceries': 2,
    'Medicine': 3,
    'Stationery': 5,
    'Sports Gear': 6,
    'Tech & Electronics': 7,
  };

  final Map<String, List<Map<String, String>>> _curatedImagePresets = {
    'Books': [
      {'title': 'Clean Code & Tech', 'url': 'https://images.unsplash.com/photo-1532012164546-f432f2e37b73?w=600'},
      {'title': 'Psychology & Finance', 'url': 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600'},
      {'title': 'Hardcover Novel', 'url': 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=600'},
      {'title': 'Academic Textbook', 'url': 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=600'},
    ],
    'Groceries': [
      {'title': 'Organic Produce', 'url': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600'},
      {'title': 'Honey & Grains', 'url': 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=600'},
    ],
    'Bakery': [
      {'title': 'Butter Croissant', 'url': 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600'},
      {'title': 'Fresh Artisan Bread', 'url': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600'},
    ],
    'Medicine': [
      {'title': 'First Aid Kit', 'url': 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=600'},
      {'title': 'Health Supplements', 'url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=600'},
    ],
    'Tech & Electronics': [
      {'title': 'Wireless Headphones', 'url': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=600'},
      {'title': 'Smart Wearable', 'url': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600'},
    ],
    'Sports Gear': [
      {'title': 'Fitness Equipment', 'url': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=600'},
      {'title': 'Badminton Racket', 'url': 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600'},
    ],
    'Stationery': [
      {'title': 'Leather Journal', 'url': 'https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=600'},
      {'title': 'Writing Desk Set', 'url': 'https://images.unsplash.com/photo-1583485088034-697b5bc54ccd?w=600'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _skuController.text = 'RAMA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _sellingPriceController.dispose();
    _purchasePriceController.dispose();
    _stockController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  bool _isUploadingImage = false;

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => _isUploadingImage = true);
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _imageUrlController.text = base64String;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.secondaryFixedDim,
            content: Text('📸 Photo uploaded from your device successfully!', style: TextStyle(color: Color(0xFF005236), fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load image: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _onCategoryChanged(String? val) {
    if (val != null) {
      setState(() {
        _selectedCategory = val;
        _selectedCategoryId = _categories[val] ?? 4;
        final presets = _curatedImagePresets[val];
        if (presets != null && presets.isNotEmpty) {
          _imageUrlController.text = presets.first['url']!;
        }
      });
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final sku = _skuController.text.trim();
    final sellingPrice = double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final imageUrl = _imageUrlController.text.trim();

    if (name.isEmpty || sku.isEmpty || sellingPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Product Name, SKU, and valid Selling Price')),
      );
      return;
    }

    final newProduct = Product(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      sku: sku,
      name: name,
      sellingPrice: sellingPrice,
      stock: stock,
      status: _publicationStatus,
      categoryId: _selectedCategoryId,
      categoryName: _selectedCategory,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
    );

    // Add to Live Catalog State & Storage
    ref.read(catalogNotifierProvider.notifier).addProduct(newProduct);
    widget.onPublished?.call('Published "$name" to $_selectedCategory');

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.secondaryFixedDim,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF005236)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '✨ "$name" published as $_publicationStatus in $_selectedCategory!',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005236)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPresets = _curatedImagePresets[_selectedCategory] ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return FrostedGlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '✨ Publish Product to Category',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Instant synchronization with Web & Mobile storefronts',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Title
              AppTextField(
                controller: _nameController,
                label: 'Product Title',
                hint: 'e.g. The Psychology of Money (Hardcover Edition)',
                prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // SKU & Category
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _skuController,
                      label: 'SKU / Barcode',
                      hint: 'RAMA-BK01',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assigned Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surfaceLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              dropdownColor: AppColors.surface,
                              items: _categories.keys.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: _onCategoryChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Price & Stock
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _sellingPriceController,
                      label: 'Selling Price (₹)',
                      hint: '499',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _purchasePriceController,
                      label: 'Cost Price (₹)',
                      hint: '299',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _stockController,
                      label: 'Stock Units',
                      hint: '20',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Image Upload / Preset Selection Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📷 Product Cover Image',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixedDim.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LIVE PREVIEW',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryFixedDim),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Thumbnail Preview Card
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProductImageView(
                          imageUrl: _imageUrlController.text,
                          width: 110,
                          height: 110,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Live Upload Button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondaryFixedDim,
                                  foregroundColor: const Color(0xFF005236),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: _isUploadingImage
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF005236)),
                                      )
                                    : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                label: Text(
                                  _isUploadingImage ? 'Loading photo...' : 'Upload Photo from Device',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                              ),
                              const SizedBox(height: 10),

                              if (_imageUrlController.text.startsWith('data:image'))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryFixedDim.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '✅ Device Photo Ready to Publish',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryFixedDim),
                                  ),
                                )
                              else ...[
                                const Text(
                                  'Or choose from curated department presets:',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: currentPresets.map((preset) {
                                    final isSelected = _imageUrlController.text == preset['url'];
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _imageUrlController.text = preset['url']!;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.secondaryFixedDim : const Color(0xFF1E293B),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSelected ? AppColors.secondaryFixedDim : const Color(0xFF334155),
                                          ),
                                        ),
                                        child: Text(
                                          preset['title']!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? const Color(0xFF005236) : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Custom URL Field
                    AppTextField(
                      controller: _imageUrlController,
                      label: 'Custom Image URL / Base64 Data String',
                      hint: 'https://... or upload above',
                      prefixIcon: const Icon(Icons.link_rounded, color: AppColors.textSecondary),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Publication Status (Draft vs Published)
              const Text('Publication State', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('PUBLISHED (Live on Store)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      selected: _publicationStatus == 'published',
                      selectedColor: AppColors.secondaryFixedDim,
                      labelStyle: TextStyle(
                        color: _publicationStatus == 'published' ? const Color(0xFF005236) : AppColors.textSecondary,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _publicationStatus = 'published');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('DRAFT (Hidden)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      selected: _publicationStatus == 'draft',
                      selectedColor: AppColors.accentAmber,
                      labelStyle: TextStyle(
                        color: _publicationStatus == 'draft' ? const Color(0xFF005236) : AppColors.textSecondary,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _publicationStatus = 'draft');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Publish Button
              AppButton(
                text: 'Publish Product to Storefront',
                icon: Icons.rocket_launch_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        );
      },
    );
  }
}
