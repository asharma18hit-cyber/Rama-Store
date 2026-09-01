// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadFileFromUrl(String url, {String? filename}) {
  final anchor = html.AnchorElement(href: url);
  if (filename != null && filename.isNotEmpty) {
    anchor.setAttribute('download', filename);
  } else {
    anchor.setAttribute('download', 'rama-store-app.apk');
  }
  anchor.style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
