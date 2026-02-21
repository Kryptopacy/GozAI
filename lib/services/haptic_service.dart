import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Service for structured haptic feedback patterns.
///
/// Provides distinct vibration patterns for different alert types,
/// allowing non-visual communication of state changes and hazards.
class HapticService {
  /// Quick pulse — general acknowledgment
  static Future<void> tap() async {
    HapticFeedback.lightImpact();
  }

  /// Strong single buzz — attention needed
  static Future<void> alert() async {
    HapticFeedback.heavyImpact();
  }

  /// Rapid triple buzz — HAZARD / STOP
  static Future<void> hazardWarning() async {
    if (await Vibration.hasVibrator() == true) {
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
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 80, 120, 80]);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Gentle sustained pulse — navigation cue
  static Future<void> navigationCue() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 200, amplitude: 100);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// Connection state change feedback
  static Future<void> connected() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 50, 100, 150]);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Mode switch confirmation
  static Future<void> modeSwitch() async {
    HapticFeedback.selectionClick();
  }
}
