import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/frosted_glass_container.dart';
import '../../../shared/widgets/hover_card.dart';
import '../../catalog/data/catalog_models.dart';
import '../../../main.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _showPublishProductDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PublishProductSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogState = ref.watch(catalogNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('STITCH ADMIN DASHBOARD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_rounded),
            tooltip: 'Publish New Product',
            onPressed: () => _showPublishProductDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Welcome Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixedDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LIVE ADMIN PORTAL',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF005236)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Rama Store v2.0 • Web & App Sync', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Metrics & Store Analytics', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 20),

            // Bento Metric Cards Grid (Google Stitch Admin Design)
            Row(
              children: [
                Expanded(
                  child: HoverCard(
                    child: FrostedGlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.currency_rupee, color: AppColors.secondaryFixedDim, size: 24),
                          SizedBox(height: 8),
                          Text('Total Revenue', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          SizedBox(height: 2),
                          Text('₹1,48,900', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          SizedBox(height: 4),
                          Text('+18.4% this month', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoverCard(
                    child: FrostedGlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.shopping_bag_outlined, color: AppColors.primaryFixedDim, size: 24),
                          SizedBox(height: 8),
                          Text('Active Orders', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          SizedBox(height: 2),
                          Text('42 Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          SizedBox(height: 4),
                          Text('12 pending dispatch', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: HoverCard(
                    child: FrostedGlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: AppColors.primaryGoldLight, size: 24),
                          const SizedBox(height: 8),
                          const Text('Total Catalog Items', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text('${catalogState.products.length} Products', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoverCard(
                    child: FrostedGlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.people_alt_outlined, color: AppColors.secondaryFixedDim, size: 24),
                          SizedBox(height: 8),
                          Text('Registered Loyalty Users', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          SizedBox(height: 2),
                          Text('1,280 Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Live Inventory Management', style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Listing', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _showPublishProductDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Product Inventory Table List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: catalogState.products.length > 8 ? 8 : catalogState.products.length,
              itemBuilder: (context, index) {
                final product = catalogState.products[index];
                return HoverCard(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory, color: AppColors.secondaryFixedDim, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                              Text('Stock: ${product.stock} units • SKU: ${product.sku} • ${product.categoryName ?? "General"}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(product.sellingPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryFixedDim),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            AppButton(
              text: 'Publish New Product to Store Catalog',
              icon: Icons.add_circle_outline_rounded,
              onPressed: () => _showPublishProductDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishProductSheet extends ConsumerStatefulWidget {
  const _PublishProductSheet();

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
      status: 'published',
      categoryId: _selectedCategoryId,
      categoryName: _selectedCategory,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
    );

    // Add to Live Catalog State
    ref.read(catalogNotifierProvider.notifier).addProduct(newProduct);

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
                '✨ "$name" successfully published to Rama Store Catalog!',
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
                        '✨ Publish New Product',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Direct live listing to Rama Store Web & Mobile',
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

              // Product Title
              AppTextField(
                controller: _nameController,
                label: 'Product Title',
                hint: 'e.g. Organic Himalayan Honey (500g)',
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
                        const Text(
                          'Category',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
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
                      label: 'Purchase Cost (₹)',
                      hint: '299',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _stockController,
                      label: 'Initial Stock',
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

              // Badge Selector
              const Text(
                'Product Highlight Badge',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Popular', 'Bestseller', 'New Arrival', 'Limited Drop'].map((badge) {
                  final isSelected = _selectedBadge == badge;
                  return ChoiceChip(
                    label: Text(badge, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textSecondary)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainer,
                    backgroundColor: AppColors.surface,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedBadge = badge);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),
              AppButton(
                text: 'Publish to Store Catalog',
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
