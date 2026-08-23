import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../main.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✨ Ready to add new listing to catalog')),
              );
            },
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
                const Text('Rama Store v2.0', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Metrics & Store Analytics', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 20),

            // Bento Metric Cards Grid (Google Stitch Admin Design)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.secondaryFixedDim.withValues(alpha: 0.4)),
                    ),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.4)),
                    ),
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
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
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
              ],
            ),

            const SizedBox(height: 28),
            Text('Quick Inventory Management', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            // Product Inventory Table List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: catalogState.products.length > 5 ? 5 : catalogState.products.length,
              itemBuilder: (context, index) {
                final product = catalogState.products[index];
                return Container(
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
                            Text('Stock: ${product.stock} units • SKU: ${product.sku}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(product.sellingPrice),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryFixedDim),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            AppButton(
              text: 'Add New Product Listing',
              icon: Icons.add,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Stitch Drag-and-Drop Media Upload Modal')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
