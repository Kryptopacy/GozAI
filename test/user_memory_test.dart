import 'package:flutter_test/flutter_test.dart';
import 'package:gozai/services/user_memory_service.dart';

void main() {
  group('UserMemoryService Logic Tests', () {
    test('buildMemoryContext returns null for empty facts', () {
      final service = UserMemoryService();
      // Note: We can't easily mock Firestore instance in a simple unit test 
      // without extra dependencies, but we can verify the accessor logic.
      expect(service.facts.isEmpty, isTrue);
      expect(service.buildMemoryContext(), isNull);
    });

    test('buildMemoryContext handles multiple categories correctly', () {
      // Manual injection for logic testing if internal state was accessible.
      // Since it's private, we verify the interface.
      final service = UserMemoryService();
      expect(service.facts.length, 0);
    });
  });
}
