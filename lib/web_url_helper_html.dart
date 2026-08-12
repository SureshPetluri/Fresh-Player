import 'dart:html' as html;

// Web implementation creating Blob URL using browser native Blob API
String createBlobUrl(List<int> bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}
