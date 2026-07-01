import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicios_ya/features/onboarding_flow/providers/onboarding_provider.dart';

void main() {
  group('isOnboardingComplete', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Returns false when user never completed onboarding', () async {
      final result = await isOnboardingComplete('non-existent-user');
      expect(result, false);
    });

    test('Returns true when user is cached as complete', () async {
      final userId = 'test-user-123';
      final prefs = await SharedPreferences.getInstance();

      // Manually set the flag as if user completed onboarding
      await prefs.setBool('onboarding_done_$userId', true);

      final result = await isOnboardingComplete(userId);
      expect(result, true);
    });

    test('Returns false when no flag is cached', () async {
      final result = await isOnboardingComplete('different-user');
      expect(result, false);
    });
  });

  group('markOnboardingComplete', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Sets the onboarding flag for user', () async {
      final userId = 'test-user-456';
      await markOnboardingComplete(userId);

      final prefs = await SharedPreferences.getInstance();
      final isComplete = prefs.getBool('onboarding_done_$userId');

      expect(isComplete, true);
    });
  });

  group('Service Categories', () {
    test('Has all 19 service categories', () {
      expect(kServiceCategories.length, 19);
    });

    test('Each category has required fields', () {
      for (final category in kServiceCategories) {
        expect(category.containsKey('id'), true);
        expect(category.containsKey('name'), true);
        expect(category.containsKey('emoji'), true);
        expect(category['id'].isNotEmpty, true);
        expect(category['name'].isNotEmpty, true);
        expect(category['emoji'].isNotEmpty, true);
      }
    });

    test('All category IDs are unique', () {
      final ids = kServiceCategories.map((c) => c['id']).toList();
      expect(ids.length, ids.toSet().length); // Unique if length equals set length
    });
  });

  group('Dominican Republic Provinces', () {
    test('Has all 32 provinces', () {
      expect(kProvinciasRD.length, 32);
    });

    test('Contains key provinces', () {
      expect(kProvinciasRD.contains('Santo Domingo'), true);
      expect(kProvinciasRD.contains('Santiago'), true);
      expect(kProvinciasRD.contains('La Romana'), true);
    });
  });
}
