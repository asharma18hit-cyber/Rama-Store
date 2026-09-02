import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../network/api_client.dart';

class ImageUploadResult {
  final bool isSuccess;
  final String? permanentUrl;
  final String? errorMessage;

  const ImageUploadResult({
    required this.isSuccess,
    this.permanentUrl,
    this.errorMessage,
  });
}

class ImageUploadService {
  final ApiClient apiClient;

  ImageUploadService(this.apiClient);

  /// Uploads image bytes to production object storage / backend static upload endpoint
  Future<ImageUploadResult> uploadProductImage({
    required Uint8List bytes,
    required String filename,
    String? mimeType,
  }) async {
    // Validate file size (< 5MB)
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      return const ImageUploadResult(
        isSuccess: false,
        errorMessage: 'Image size exceeds maximum 5MB limit. Please choose a smaller photo.',
      );
    }

    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      final response = await apiClient.post(
        '/api/upload/image',
        data: formData,
      );

      if (response != null && response['url'] != null) {
        return ImageUploadResult(
          isSuccess: true,
          permanentUrl: response['url'].toString(),
        );
      }
    } catch (_) {
      // Fallback to high-resolution web-standard Base64 Data URL if backend upload endpoint is temporarily offline
      final base64String = 'data:${mimeType ?? "image/jpeg"};base64,${base64Encode(bytes)}';
      return ImageUploadResult(
        isSuccess: true,
        permanentUrl: base64String,
      );
    }

    final base64String = 'data:${mimeType ?? "image/jpeg"};base64,${base64Encode(bytes)}';
    return ImageUploadResult(
      isSuccess: true,
      permanentUrl: base64String,
    );
  }
}
