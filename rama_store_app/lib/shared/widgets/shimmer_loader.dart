import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceLight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoader(width: double.infinity, height: 110, borderRadius: 8),
          const SizedBox(height: 12),
          const ShimmerLoader(width: 80, height: 14),
          const SizedBox(height: 6),
          const ShimmerLoader(width: 140, height: 18),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerLoader(width: 60, height: 20),
              ShimmerLoader(width: 32, height: 32, borderRadius: 16),
            ],
          ),
        ],
      ),
    );
  }
}
