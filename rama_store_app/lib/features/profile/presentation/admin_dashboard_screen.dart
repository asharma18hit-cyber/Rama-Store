import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/frosted_glass_container.dart';
import '../../../shared/widgets/hover_card.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/presentation/catalog_notifier.dart';
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

  // In-memory audit trail records
  final List<Map<String, String>> _auditLogs = [
    {'action': 'ADMIN_LOGIN', 'detail': 'Admin logged in from Web Session', 'time': 'Just now'},
    {'action': 'STOCK_LOCK', 'detail': '2 units reserved for Order #TRK-882941', 'time': '5 mins ago'},
    {'action': 'PRODUCT_PUBLISHED', 'detail': 'Published "Organic Mountain Tea" to Grocery', 'time': '12 mins ago'},
    {'action': 'CATEGORY_CREATED', 'detail': 'Created new department "Tech-Fab"', 'time': '1 hour ago'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPublishProductDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PublishProductSheet(
        onPublished: (logDetail) {
          setState(() {
            _auditLogs.insert(0, {
              'action': 'PRODUCT_PUBLISHED',
              'detail': logDetail,
              'time': 'Just now',
            });
          });
        },
      ),
    );
  }

  void _showCreateCategoryDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add New Store Category', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: AppTextField(
          controller: nameController,
          label: 'Category Name',
          hint: 'e.g. Sports & Outdoors',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryFixedDim),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final newCat = Category(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  name: name,
                );
                ref.read(catalogNotifierProvider.notifier).addCategory(newCat);
                setState(() {
                  _auditLogs.insert(0, {
                    'action': 'CATEGORY_CREATED',
                    'detail': 'Created category "$name"',
                    'time': 'Just now',
                  });
                });
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.secondaryFixedDim,
                    content: Text('✨ Category "$name" created successfully!', style: const TextStyle(color: Color(0xFF005236), fontWeight: FontWeight.bold)),
                  ),
                );
              }
            },
            child: const Text('Create Category', style: TextStyle(color: Color(0xFF005236), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogNotifierProvider);
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
            const Text('Rama Store v3.0 Master', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
            Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Products & Publishing'),
            Tab(icon: Icon(Icons.category_rounded), text: 'Categories'),
            Tab(icon: Icon(Icons.shopping_cart_checkout_rounded), text: 'Orders'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Audit Trail'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Metrics & Overview
          _buildDashboardTab(catalogState),

          // 2. Products Management & Publishing
          _buildProductsTab(catalogState),

          // 3. Category Manager
          _buildCategoriesTab(catalogState),

          // 4. Orders Management
          _buildOrdersTab(),

          // 5. Audit Trail Logs
          _buildAuditLogsTab(),
        ],
      ),
    );
  }

  // TAB 1: METRICS DASHBOARD
  Widget _buildDashboardTab(CatalogState catalogState) {
    final publishedCount = catalogState.products.where((p) => p.status == 'published').length;
    final draftCount = catalogState.products.where((p) => p.status != 'published').length;
    final lowStockCount = catalogState.products.where((p) => p.stock < 5).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Real-Time Store Metrics', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),

          // Metrics Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard('Total Revenue (August)', '₹1,48,900', '+18.4%', Icons.currency_rupee, AppColors.secondaryFixedDim, true),
              _buildMetricCard('Active Orders', '42 Orders', '12 processing', Icons.shopping_bag_outlined, AppColors.primaryFixedDim, false),
              _buildMetricCard('Published Live Items', '$publishedCount Products', '$draftCount in draft', Icons.inventory_2_outlined, AppColors.primaryGoldLight, false),
              _buildMetricCard('Low Stock Alerts', '$lowStockCount Items', 'Needs Reorder', Icons.warning_amber_rounded, AppColors.error, false),
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
        width: 240,
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

  // TAB 2: PRODUCTS & PUBLISHING
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
              Text('Products Management (${filtered.length})', style: Theme.of(context).textTheme.titleLarge),
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

          // Filters Bar
          Wrap(
            spacing: 8,
            children: ['all', 'published', 'draft', 'unpublished'].map((status) {
              final isSel = _selectedStatusFilter == status;
              return ChoiceChip(
                label: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppColors.textSecondary)),
                selected: isSel,
                selectedColor: AppColors.primaryContainer,
                backgroundColor: AppColors.surface,
                onSelected: (val) {
                  if (val) setState(() => _selectedStatusFilter = status);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Products List
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = filtered[index];
                final isPublished = product.status == 'published';

                return FrostedGlassContainer(
                  padding: const EdgeInsets.all(14),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory, color: AppColors.secondaryFixedDim),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPublished ? AppColors.success.withValues(alpha: 0.2) : AppColors.warning.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    product.status.toUpperCase(),
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isPublished ? AppColors.success : AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Category: ${product.categoryName ?? "General"} • SKU: ${product.sku} • Stock: ${product.stock} units',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(product.sellingPrice),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.secondaryFixedDim),
                      ),
                      const SizedBox(width: 14),

                      // Publish / Unpublish Action Toggle
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isPublished ? AppColors.warning : AppColors.success),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                        ),
                        icon: Icon(isPublished ? Icons.visibility_off : Icons.publish, size: 14, color: isPublished ? AppColors.warning : AppColors.success),
                        label: Text(
                          isPublished ? 'Unpublish' : 'Publish',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPublished ? AppColors.warning : AppColors.success),
                        ),
                        onPressed: () {
                          final newStatus = isPublished ? 'unpublished' : 'published';
                          ref.read(catalogNotifierProvider.notifier).updateProductStatus(product.id, newStatus);
                          setState(() {
                            _auditLogs.insert(0, {
                              'action': isPublished ? 'PRODUCT_UNPUBLISHED' : 'PRODUCT_PUBLISHED',
                              'detail': '${isPublished ? "Unpublished" : "Published"} "${product.name}"',
                              'time': 'Just now',
                            });
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Product "${product.name}" is now $newStatus!')),
                          );
                        },
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

  // TAB 3: CATEGORIES
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
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryFixedDim),
                icon: const Icon(Icons.add, color: Color(0xFF005236)),
                label: const Text('Add Category', style: TextStyle(color: Color(0xFF005236), fontWeight: FontWeight.bold)),
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
                final count = catalogState.products.where((p) => p.categoryId == cat.id || p.categoryName == cat.name).length;

                return FrostedGlassContainer(
                  padding: const EdgeInsets.all(14),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.folder_open_rounded, color: AppColors.secondaryFixedDim),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Text('$count Products', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
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

  // TAB 4: ORDERS
  Widget _buildOrdersTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Orders Fulfillment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildAdminOrderRow('TRK-982410', 'Rahul Sharma', '₹2,499', 'Paid', '2x Sourdough Bread, 1x Clean Code Book'),
                _buildAdminOrderRow('TRK-741203', 'Anita Verma', '₹899', 'Processing', '1x Himalayan Pure Honey'),
                _buildAdminOrderRow('TRK-551029', 'Vikram Singh', '₹1,249', 'Shipped', '1x Titanium Fiber Gear Pack'),
                _buildAdminOrderRow('TRK-440192', 'Priya Patel', '₹499', 'Delivered', '1x Bakery Croissant Box'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminOrderRow(String trk, String customer, String amount, String status, String items) {
    Color statusColor = AppColors.info;
    if (status == 'Delivered') statusColor = AppColors.success;
    if (status == 'Processing') statusColor = AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Order #$trk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Text('• $customer', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(items, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryFixedDim)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // TAB 5: AUDIT LOGS
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
  final _imageUrlController = TextEditingController(text: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=800');

  String _selectedCategory = 'Groceries';
  int _selectedCategoryId = 2;
  String _selectedBadge = 'Popular';
  String _publicationStatus = 'published';
  bool _isPublishing = false;

  final Map<String, int> _categories = {
    'Bakery': 1,
    'Groceries': 2,
    'Medicine': 3,
    'Books': 4,
    'Stationery': 5,
    'Sports': 6,
    'Tech-Fab': 7,
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

    setState(() => _isPublishing = true);

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

    // Add to Live Catalog State
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
                '✨ "$name" published as $_publicationStatus to $_selectedCategory!',
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
                hint: 'e.g. Wireless Noise-Cancelling Headphones',
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
                      hint: 'RAMA-001',
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
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedCategory = val;
                                    _selectedCategoryId = _categories[val] ?? 1;
                                  });
                                }
                              },
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
              const SizedBox(height: 16),

              // Image URL
              AppTextField(
                controller: _imageUrlController,
                label: 'Cover Image URL',
                hint: 'https://images.unsplash.com/...',
                prefixIcon: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Publication Status (Draft vs Published)
              const Text('Publication State', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('PUBLISHED (Live)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      selected: _publicationStatus == 'published',
                      selectedColor: AppColors.secondaryFixedDim,
                      backgroundColor: AppColors.surface,
                      onSelected: (val) {
                        if (val) setState(() => _publicationStatus = 'published');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('SAVE DRAFT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      selected: _publicationStatus == 'draft',
                      selectedColor: AppColors.primaryContainer,
                      backgroundColor: AppColors.surface,
                      onSelected: (val) {
                        if (val) setState(() => _publicationStatus = 'draft');
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              AppButton(
                text: _publicationStatus == 'published' ? 'Publish to Live Catalog' : 'Save as Draft',
                icon: Icons.rocket_launch_rounded,
                isLoading: _isPublishing,
                onPressed: _submit,
              ),
            ],
          ),
        );
      },
    );
  }
}
