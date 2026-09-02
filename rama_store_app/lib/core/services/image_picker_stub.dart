import 'dart:convert';
import 'package:image_picker/image_picker.dart';

Future<String?> pickImageAsBase64() async {
  try {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  } catch (_) {}
  return null;
}
