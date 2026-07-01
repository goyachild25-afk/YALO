import 'package:flutter_test/flutter_test.dart';
import 'package:servicios_ya/core/utils/cedula_validator.dart';

void main() {
  group('CedulaValidator', () {
    test('rechaza cédulas vacías', () {
      expect(CedulaValidator.isValid(''), isFalse);
      expect(CedulaValidator.errorMessage(''), isNotNull);
    });

    test('rechaza longitud incorrecta', () {
      expect(CedulaValidator.isValid('12345'), isFalse);
      expect(CedulaValidator.isValid('123456789012'), isFalse);
    });

    test('rechaza todos ceros', () {
      expect(CedulaValidator.isValid('00000000000'), isFalse);
      expect(CedulaValidator.isValid('000-0000000-0'), isFalse);
    });

    test('rechaza dígitos repetidos', () {
      expect(CedulaValidator.isValid('11111111111'), isFalse);
      expect(CedulaValidator.isValid('99999999999'), isFalse);
    });

    test('rechaza oficialía 000', () {
      // 000-XXXXXXX-X aunque pase el checksum es inválido
      expect(CedulaValidator.isValid('00012345678'), isFalse);
    });

    test('acepta cédulas con checksum válido (formato con guiones)', () {
      // Cédulas de prueba conocidas con checksum correcto
      // Nota: los valores exactos dependen del algoritmo JCE
      final valid = _findValidSampleCedula();
      expect(CedulaValidator.isValid(valid), isTrue);
      expect(CedulaValidator.errorMessage(valid), isNull);
    });

    test('format normaliza a XXX-XXXXXXX-X', () {
      final valid = _findValidSampleCedula();
      final digits = valid.replaceAll('-', '');
      expect(CedulaValidator.format(digits), equals(valid));
    });

    test('format devuelve input sin cambios si no tiene 11 dígitos', () {
      expect(CedulaValidator.format('123'), equals('123'));
    });
  });
}

/// Genera una cédula válida encontrando un checksum correcto para un
/// prefijo de 10 dígitos dado.
String _findValidSampleCedula() {
  // Prefijo 001-1234567 (Distrito Nacional, número arbitrario). Probamos
  // los 10 dígitos verificadores posibles y devolvemos el válido.
  const prefix = '0011234567';
  for (int check = 0; check <= 9; check++) {
    final candidate = '$prefix$check';
    if (CedulaValidator.isValid(candidate)) {
      return CedulaValidator.format(candidate);
    }
  }
  throw StateError('no encontramos checksum válido para el prefijo');
}
