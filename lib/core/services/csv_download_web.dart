// Implementación web real: arma un Blob y dispara la descarga con un
// <a download> temporal, sin necesidad de backend.
import 'dart:convert';
import 'dart:html' as html;

const String _utf8Bom = '﻿';

void downloadCsv(String filename, String csvContent) {
  // BOM UTF-8 para que Excel abra tildes/ñ correctamente.
  final bytes = utf8.encode('$_utf8Bom$csvContent');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
