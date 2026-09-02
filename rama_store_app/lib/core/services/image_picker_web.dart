import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> pickImageAsBase64() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()..accept = 'image/png,image/jpeg,image/jpg,image/webp';
  uploadInput.click();

  uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        completer.complete(reader.result as String?);
      });
      reader.onError.listen((_) {
        completer.complete(null);
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
