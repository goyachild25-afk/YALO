import 'package:flutter_test/flutter_test.dart';
import 'package:servicios_ya/shared/models/service_category_model.dart';

void main() {
  group('broadToGranularCategoryIds', () {
    test('todas las categorías amplias del cliente tienen mapeo', () {
      for (final cat in serviceCategories) {
        expect(
          broadToGranularCategoryIds.containsKey(cat.id),
          isTrue,
          reason:
              'La categoría amplia "${cat.id}" no tiene mapeo a granulares — '
              'prestadores que la ofrezcan nunca recibirán solicitudes.',
        );
      }
    });

    test('no hay duplicados en las listas granulares de una misma amplia',
        () {
      broadToGranularCategoryIds.forEach((broad, granulars) {
        final set = granulars.toSet();
        expect(set.length, equals(granulars.length),
            reason: 'La categoría "$broad" tiene granulares duplicadas');
      });
    });

    test('categorías críticas incluyen sus granulares esperadas', () {
      // Regresión: eran omisiones históricas
      expect(broadToGranularCategoryIds['cleaning'], contains('laundry'));
      expect(broadToGranularCategoryIds['garden'], contains('yard_maintenance'));
      expect(
          broadToGranularCategoryIds['maintenance'], contains('ac_maintenance'));
    });
  });
}
