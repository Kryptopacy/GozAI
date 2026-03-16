import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

/// Service to bridge the Flutter app's Gemini Live session with the Python ADK Backend.
/// 
/// Employs Agent-to-Agent delegation: The conversational Gemini Live agent routes
/// specialized medical and statistical queries to the ADK agent, which performs RAG.
class AdkBridgeService {
  static const _timeout = Duration(seconds: 15);

  /// Delegates a query to the Python ADK backend.
  /// Handles errors gracefully so the conversational agent can inform the user
  /// rather than the app crashing.
  Future<String> consultBackendAgent(String query) async {
    final url = '${AppConfig.adkBackendUrl}/api/agents/gozai_agent/run';
    debugPrint('AdkBridgeService: Delegating to ADK Agent at $url with query: "$query"');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"input": query}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final output = json['output'] as String?;
        debugPrint('AdkBridgeService: ADK Agent responded successfully.');
        return output ?? 'The backend specialized agent returned an empty response.';
      } else {
        debugPrint('AdkBridgeService: HTTP ${response.statusCode} - ${response.body}');
        return 'The specialized backend agent returned an error (Code: ${response.statusCode}).';
      }
    } on TimeoutException {
      debugPrint('AdkBridgeService: Request timed out.');
      return 'The specialized backend agent took too long to respond. The service might be sleeping or unreachable.';
    } catch (e) {
      debugPrint('AdkBridgeService: Network error: $e');
      return 'I am currently unable to reach the specialized medical backend. Local network error or the server is not running.';
    }
  }
}
