import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;

  const RatingStars({
    Key? key,
    required this.rating,
    this.size = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: AppColors.accentAmber, size: size);
        } else if (index < rating && (rating - index) >= 0.5) {
          return Icon(Icons.star_half, color: AppColors.accentAmber, size: size);
        } else {
          return Icon(Icons.star_border, color: AppColors.textMuted, size: size);
        }
      }),
    );
  }
}
