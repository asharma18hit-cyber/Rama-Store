import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';

class ProductImageView extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProductImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      content = Container(
        width: width,
        height: height,
        color: const Color(0xFF1E293B),
        child: const Center(
          child: Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 28),
        ),
      );
    } else if (imageUrl!.startsWith('data:image')) {
      try {
        final commaIndex = imageUrl!.indexOf(',');
        final base64Data = commaIndex != -1 ? imageUrl!.substring(commaIndex + 1) : imageUrl!;
        final Uint8List bytes = base64Decode(base64Data);
        content = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        content = _buildFallback();
      }
    } else {
      content = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: const Color(0xFF1E293B),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryFixedDim),
            ),
          ),
        ),
        errorWidget: (context, url, err) => Image.network(
          imageUrl!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 28),
      ),
    );
  }
}
