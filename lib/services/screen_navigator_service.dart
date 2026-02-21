import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_service.dart';

/// UI Navigator / Screen Navigator — the "Digital Accessibility Bridge"
///
/// This service captures the device screen and sends it to Gemini for
/// semantic understanding, enabling voice-guided interaction with app
/// UIs that screen readers cannot fully interpret.
///
/// Key capabilities GozAI provides that VoiceOver/TalkBack cannot:
/// 1. **Context from magnification** — describes the full page layout
///    when the user can only see a zoomed-in portion
/// 2. **Visual-only content** — reads CAPTCHAs, color-coded indicators,
///    image-based buttons without accessibility labels
/// 3. **Semantic understanding** — "This is a checkout screen" vs just
///    reading individual element labels sequentially
/// 4. **Form assistance** — identifies which fields are filled, which
///    have errors, what the validation message says
class ScreenNavigatorService extends ChangeNotifier {
  GeminiLiveService? _geminiService;
  bool _isActive = false;
  String _lastScreenDescription = '';
  Timer? _screenCaptureTimer;

  bool get isActive => _isActive;
  String get lastScreenDescription => _lastScreenDescription;

  /// Bind to the Gemini Live service for sending screen captures.
  void bindGeminiService(GeminiLiveService service) {
    _geminiService = service;
  }

  /// Start screen navigation mode.
  ///
  /// Captures the screen periodically and sends it to Gemini with
  /// UI-specific instructions.
  void startNavigation() {
    if (_isActive) return;
    _isActive = true;
    notifyListeners();
    debugPrint('ScreenNavigator: Navigation mode started');
  }

  /// Stop screen navigation mode.
  void stopNavigation() {
    _screenCaptureTimer?.cancel();
    _screenCaptureTimer = null;
    _isActive = false;
    notifyListeners();
    debugPrint('ScreenNavigator: Navigation mode stopped');
  }

  /// Analyze a screenshot and get a structured description.
  ///
  /// This is the core method — takes a screenshot (as JPEG bytes)
  /// and sends it to Gemini with UI-analysis-specific context.
  Future<void> analyzeScreen(Uint8List screenshotJpeg) async {
    if (_geminiService == null || !_geminiService!.isConnected) {
      debugPrint('ScreenNavigator: Cannot analyze — Gemini not connected');
      return;
    }

    // Send the screenshot to Gemini
    _geminiService!.sendVideoFrame(screenshotJpeg);

    // Send a UI-specific analysis instruction
    _geminiService!.sendText(
      'You are in UI Navigator mode. Analyze this screen and describe: '
      '1) What type of screen this is (settings, form, list, etc.) '
      '2) All interactive elements with their positions '
      '3) Any text content, including small labels and error messages '
      '4) The state of toggles, checkboxes, and selections '
      '5) Any color-coded indicators and what the colors represent. '
      'Be concise but thorough.',
    );

    debugPrint('ScreenNavigator: Screenshot sent for analysis');
  }

  /// Handle a user voice command about the screen.
  ///
  /// Examples:
  /// - "What's on this screen?"
  /// - "Find the WiFi setting"
  /// - "Read the error message"
  /// - "What color is the indicator?"
  /// - "Is the form filled out?"
  void handleVoiceCommand(String command) {
    if (_geminiService == null || !_geminiService!.isConnected) return;

    _geminiService!.sendText(
      'The user is asking about a phone screen they cannot see clearly. '
      'Their question: "$command". '
      'Answer with spatial guidance (top-left, center, etc.) '
      'and actionable instructions.',
    );
  }

  /// Analyze a specific region of the screen (when user points camera
  /// at their phone screen while magnified).
  void analyzeRegion(Uint8List regionJpeg, String context) {
    if (_geminiService == null || !_geminiService!.isConnected) return;

    _geminiService!.sendVideoFrame(regionJpeg);
    _geminiService!.sendText(
      'The user is looking at a zoomed-in portion of their phone screen. '
      'They can only see this small section. $context '
      'Describe what is visible and help them understand the broader context. '
      'What else might be on this screen that they cannot see?',
    );
  }

  /// Solve a visual CAPTCHA by describing the challenge.
  void solveCaptcha(Uint8List captchaJpeg) {
    if (_geminiService == null || !_geminiService!.isConnected) return;

    _geminiService!.sendVideoFrame(captchaJpeg);
    _geminiService!.sendText(
      'This is a CAPTCHA or visual verification challenge that the user '
      'cannot solve due to low vision. Please describe what the CAPTCHA '
      'shows or asks. If it contains text, read it exactly. If it asks '
      'to select images (like "select all traffic lights"), describe '
      'which grid positions contain the target objects.',
    );
  }

  /// Interpret color-coded UI elements.
  void interpretColors(Uint8List screenshotJpeg) {
    if (_geminiService == null || !_geminiService!.isConnected) return;

    _geminiService!.sendVideoFrame(screenshotJpeg);
    _geminiService!.sendText(
      'The user has color vision difficulties. Identify all color-coded '
      'elements on this screen and describe what each color means: '
      'status indicators, progress bars, warning icons, success/error '
      'states, highlighted selections. Translate colors into words.',
    );
  }

  /// Update the last screen description (from Gemini response).
  void updateDescription(String description) {
    _lastScreenDescription = description;
    notifyListeners();
  }

  @override
  void dispose() {
    stopNavigation();
    super.dispose();
  }
}
