// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadFileFromUrl(String url, {String? filename}) {
  final targetName = filename ?? 'samaur-mart-app.apk';
  final resolvedUrl = url.startsWith('http') ? url : '${html.window.location.origin}$url';

  try {
    final anchor = html.AnchorElement(href: resolvedUrl)
      ..setAttribute('download', targetName)
      ..setAttribute('target', '_self')
      ..setAttribute('rel', 'noopener noreferrer')
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } catch (_) {
    html.window.open(resolvedUrl, '_blank');
  }
}
