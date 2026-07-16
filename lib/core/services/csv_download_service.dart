// Import condicional: en Flutter web usa la implementación real (dart:html);
// en cualquier otra plataforma (o en `flutter test` sobre la VM) usa el stub.
import 'csv_download_stub.dart' if (dart.library.html) 'csv_download_web.dart'
    as impl;

/// Descarga de reportes CSV desde el navegador (solo tiene efecto en web).
class CsvDownloadService {
  CsvDownloadService._();

  static void download(String filename, String csvContent) =>
      impl.downloadCsv(filename, csvContent);

  /// Escapa un valor para una celda CSV (RFC 4180): entre comillas dobles,
  /// duplicando las comillas internas.
  static String field(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';
}
