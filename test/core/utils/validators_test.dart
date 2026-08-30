import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/utils/validators.dart';

void main() {
  group('Validators - validateFullName', () {
    test('returns error when value is null', () {
      final result = Validators.validateFullName(null);
      expect(result, equals('Please enter your full name'));
    });

    test('returns error when value is empty string', () {
      final result = Validators.validateFullName('');
      expect(result, equals('Please enter your full name'));
    });

    test('returns error when value is whitespace only', () {
      final result = Validators.validateFullName('   ');
      expect(result, equals('Please enter your full name'));
    });

    test('returns error when trimmed name is less than 2 characters', () {
      expect(
        Validators.validateFullName('A'),
        equals('Name must be at least 2 characters'),
      );
      expect(
        Validators.validateFullName(' B '),
        equals('Name must be at least 2 characters'),
      );
    });

    test('returns null when name is exactly 2 characters', () {
      final result = Validators.validateFullName('Jo');
      expect(result, isNull);
    });

    test('returns null when name is valid full name', () {
      final result = Validators.validateFullName('John Doe');
      expect(result, isNull);
    });

    test('returns null when name contains hyphens and accents', () {
      final result = Validators.validateFullName('María-José');
      expect(result, isNull);
    });
  });
}
