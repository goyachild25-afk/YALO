import 'package:flutter_test/flutter_test.dart';
import 'package:serviciosya/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('Supabase URL is configured', () {
      expect(AppConstants.supabaseUrl.isNotEmpty, true);
      expect(AppConstants.supabaseUrl.contains('supabase.co'), true);
    });

    test('Supabase Anon Key is configured', () {
      expect(AppConstants.supabaseAnonKey.isNotEmpty, true);
      expect(AppConstants.supabaseAnonKey.length, greaterThan(50));
    });

    test('Google Maps API Key is configured', () {
      expect(AppConstants.googleMapsApiKey.isNotEmpty, true);
      expect(AppConstants.googleMapsApiKey.startsWith('AIza'), true);
    });

    test('Fee calculations are valid', () {
      expect(AppConstants.clientFee, 0.05);
      expect(AppConstants.providerFee, 0.05);
      expect(AppConstants.platformCommission, 0.10);
    });

    test('Default radius is reasonable', () {
      expect(AppConstants.defaultRadius, 50.0);
      expect(AppConstants.defaultRadius, greaterThan(0));
    });

    test('Max photos per profile is reasonable', () {
      expect(AppConstants.maxPhotosPerProfile, 6);
      expect(AppConstants.maxPhotosPerProfile, greaterThan(0));
    });

    test('Service categories list is not empty', () {
      expect(AppConstants.serviceCategories, isNotEmpty);
      expect(AppConstants.serviceCategories.length, greaterThan(0));
      expect(AppConstants.serviceCategories.first, isNotEmpty);
    });

    test('All service categories are non-empty strings', () {
      for (final category in AppConstants.serviceCategories) {
        expect(category, isNotEmpty);
        expect(category, isA<String>());
      }
    });
  });
}
