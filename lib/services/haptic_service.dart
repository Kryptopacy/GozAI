import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:web/web.dart' as web;

/// Service for structured haptic feedback patterns.
///
/// Provides distinct vibration patterns for different alert types,
/// allowing non-visual communication of state changes and hazards.
///
/// Platform support:
/// - **iOS Native**: Uses UIFeedbackGenerator / CoreHaptics via Flutter's
///   HapticFeedback class. Full support.
/// - **Android Native**: Uses the `vibration` package for custom patterns.
///   Full support including intensity levels.
/// - **iOS/Android Web (Safari/Chrome)**: navigator.vibrate() is blocked on
///   iOS Safari. We use a timed Web Audio API oscillator burst (20–120ms) as
///   a tactile substitute. This creates an audible+physical "click" sensation
///   via the speaker which is the accepted web workaround.
class HapticService {
  /// Play a short Web Audio oscillator burst as an audible haptic substitute
  /// AND attempt the iOS silent switch click exploit for tactile feedback.
  static void _webTactileClick({
    double frequency = 200.0,
    int durationMs = 20,
  }) {
    if (!kIsWeb) return;

    try {
      // 1. Trigger iOS silent switch haptic hack
      final label = web.document.getElementById('haptic-label');
      if (label != null) {
        (label as web.HTMLElement).click();
      }
    } catch (e) {
      debugPrint('HapticService: iOS Web switch click failed: $e');
    }

    try {
      // 2. Play audible fallback click
      final ctx = web.AudioContext();
      final oscillator = ctx.createOscillator();
      final gainNode = ctx.createGain();

      oscillator.type = 'sine';
      oscillator.frequency.value = frequency;

      // Fast attack, immediate decay — sounds + feels like a tap
      gainNode.gain.setValueAtTime(0.001, ctx.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.5, ctx.currentTime + 0.005);
      gainNode.gain.exponentialRampToValueAtTime(
        0.001,
        ctx.currentTime + durationMs / 1000.0,
      );

      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);
      oscillator.start();
      oscillator.stop(ctx.currentTime + durationMs / 1000.0);
    } catch (e) {
      debugPrint('HapticService: Web Audio fallback failed: $e');
    }
  }

  /// Quick pulse — general acknowledgment
  static Future<void> tap() async {
    if (kIsWeb) {
      _webTactileClick(frequency: 300.0, durationMs: 20);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Strong single buzz — attention needed
  static Future<void> alert() async {
    if (kIsWeb) {
      _webTactileClick(frequency: 150.0, durationMs: 60);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// Rapid triple buzz — HAZARD / STOP
  static Future<void> hazardWarning() async {
    // NYU Synchronized Vibro-Acoustic Feedback:
    // Fire a system alert sound AT THE EXACT SAME TIME as the haptic impact.
    // This semantic pairing requires less cognitive load than unsynced separate warnings.
    await SystemSound.play(SystemSoundType.alert);

    if (kIsWeb) {
      // Three rapid clicks with slight pitch drop
      _webTactileClick(frequency: 180.0, durationMs: 40);
      Future.delayed(
        const Duration(milliseconds: 90),
        () => _webTactileClick(frequency: 160.0, durationMs: 40),
      );
      Future.delayed(
        const Duration(milliseconds: 180),
        () => _webTactileClick(frequency: 140.0, durationMs: 40),
      );
    } else if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(
        pattern: [0, 100, 50, 100, 50, 100],
        intensities: [0, 255, 0, 255, 0, 255],
      );
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// Double tap — person detected
  static Future<void> personDetected() async {
    if (kIsWeb) {
      _webTactileClick(frequency: 260.0, durationMs: 30);
      Future.delayed(
        const Duration(milliseconds: 120),
        () => _webTactileClick(frequency: 260.0, durationMs: 30),
      );
    } else if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 80, 120, 80]);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Gentle sustained pulse — navigation cue
  static Future<void> navigationCue() async {
    if (kIsWeb) {
      _webTactileClick(frequency: 220.0, durationMs: 50);
    } else if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 200, amplitude: 100);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// Connection state change feedback
  static Future<void> connected() async {
    if (kIsWeb) {
      _webTactileClick(frequency: 350.0, durationMs: 25);
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _webTactileClick(frequency: 420.0, durationMs: 40),
      );
    } else if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 50, 100, 150]);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Gentle, warm single pulse - safe path confirmed (Reassurance)
  static Future<void> safePathConfirm() async {
    if (kIsWeb) {
      _webTactileClick(frequency: 200.0, durationMs: 25);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Distinctive pattern for environment successfully mapped
  static Future<void> environmentKnown() async {
    if (kIsWeb) {
      _webTactileClick(frequency: 300.0, durationMs: 20);
      Future.delayed(
        const Duration(milliseconds: 150),
        () => _webTactileClick(frequency: 400.0, durationMs: 30),
      );
    } else if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 50, 100, 100]);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Mode switch confirmation
  static Future<void> modeSwitch() async {
    if (kIsWeb) {
      _webTactileClick(frequency: 280.0, durationMs: 15);
    } else {
      HapticFeedback.selectionClick();
    }
  }
}
