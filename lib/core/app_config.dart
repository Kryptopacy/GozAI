import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide configuration loaded from environment variables.
class AppConfig {
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? 'gozai-app';

  /// Gemini Multimodal Live API WebSocket endpoint
  static String get geminiLiveWsUrl =>
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$geminiApiKey';

  /// Gemini model for multimodal live
  static const String geminiModel = 'models/gemini-2.0-flash-live-001';

  /// Camera frame rate for continuous monitoring (frames per second)
  static const double cameraFps = 1.0;

  /// Audio recording sample rate (Hz) — Gemini expects 16kHz
  static const int audioInputSampleRate = 16000;

  /// Audio playback sample rate (Hz) — Gemini outputs 24kHz
  static const int audioOutputSampleRate = 24000;

  /// Validate that required config is present
  static bool get isConfigured => geminiApiKey.isNotEmpty;
}
