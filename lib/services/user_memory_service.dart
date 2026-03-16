import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Persistent user memory service — gives GozAI a companion-grade memory.
///
/// Stores and retrieves key facts about the user across sessions via Firestore.
/// Examples: medications, caregiver name, familiar locations, preferences.
///
/// Gemini can autonomously write to this memory by calling the `rememberFact` tool.
/// On session start, the memory is loaded and injected as silent system context.
class UserMemoryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'user_memory';
  static const int _maxFacts = 50;

  List<Map<String, dynamic>> _facts = [];

  /// All currently loaded facts.
  List<Map<String, dynamic>> get facts => List.unmodifiable(_facts);

  /// Loads all stored facts for [userId] from Firestore.
  /// Call this when the session starts.
  Future<void> loadMemory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('facts')
          .orderBy('timestamp', descending: true)
          .limit(_maxFacts)
          .get();

      _facts = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      debugPrint('UserMemoryService: Loaded ${_facts.length} facts for user $userId');
      notifyListeners();
    } catch (e) {
      debugPrint('UserMemoryService: Failed to load memory: $e');
    }
  }

  /// Stores a new fact for [userId]. Gemini calls this via the `rememberFact` tool.
  Future<void> storeFact({
    required String userId,
    required String category,
    required String fact,
  }) async {
    try {
      final factData = {
        'category': category,
        'fact': fact,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('facts')
          .add(factData);

      // Also add locally for immediate use
      _facts.insert(0, {
        'category': category,
        'fact': fact,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Cap local memory
      if (_facts.length > _maxFacts) {
        _facts = _facts.sublist(0, _maxFacts);
      }

      debugPrint('UserMemoryService: Stored fact [$category]: $fact');
      notifyListeners();
    } catch (e) {
      debugPrint('UserMemoryService: Failed to store fact: $e');
    }
  }

  /// Builds a context string for injection into Gemini's system prompt.
  /// Returns null if no facts are available.
  String? buildMemoryContext() {
    if (_facts.isEmpty) return null;

    final buffer = StringBuffer('[SYSTEM - USER MEMORY (from previous sessions)]\n');
    buffer.writeln('The following are things you have remembered about the user:');

    for (final fact in _facts) {
      final category = fact['category'] ?? 'general';
      final content = fact['fact'] ?? '';
      buffer.writeln('- [$category] $content');
    }

    buffer.writeln('Use this knowledge naturally in conversation. Do NOT read it back as a list.');
    return buffer.toString();
  }
}
