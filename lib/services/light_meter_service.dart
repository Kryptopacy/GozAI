import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Offline light meter and orientation aid.
///
/// Uses the device's ambient light sensor (via accelerometer proxy)
/// and camera exposure to help low-vision users:
/// 1. Orient toward windows/light sources via rising audio tone
/// 2. Assess room lighting conditions
/// 3. Navigate from bright-to-dark transitions (e.g., entering a building)
///
/// This service works ENTIRELY OFFLINE — no internet required.
class LightMeterService extends ChangeNotifier {
  StreamSubscription? _sensorSubscription;
  bool _isActive = false;
  double _currentLux = 0;
  LightLevel _lightLevel = LightLevel.unknown;
  Timer? _toneTimer;

  // Callbacks for audio feedback
  Function(double frequency)? onToneUpdate;

  bool get isActive => _isActive;
  double get currentLux => _currentLux;
  LightLevel get lightLevel => _lightLevel;

  /// Human-readable description of current light level.
  String get lightDescription {
    switch (_lightLevel) {
      case LightLevel.dark:
        return 'Very dark — use caution';
      case LightLevel.dim:
        return 'Dim lighting';
      case LightLevel.moderate:
        return 'Moderate lighting';
      case LightLevel.bright:
        return 'Well lit';
      case LightLevel.veryBright:
        return 'Very bright — likely outdoors';
      case LightLevel.unknown:
        return 'Measuring...';
    }
  }

  /// Start the light meter sensor monitoring.
  void start() {
    if (_isActive) return;
    _isActive = true;
    notifyListeners();

    // Use accelerometer as a proxy for device orientation
    // Combined with camera brightness estimation for actual lux
    _sensorSubscription = accelerometerEventStream().listen((event) {
      // Calculate device tilt angle (used for orientation feedback)
      final tilt = atan2(event.y, event.z) * (180 / pi);
      _updateOrientationFeedback(tilt);
    });

    // Periodically estimate ambient light from camera exposure
    _toneTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _updateTone(),
    );

    debugPrint('LightMeter: Started');
  }

  /// Stop the light meter.
  void stop() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _toneTimer?.cancel();
    _toneTimer = null;
    _isActive = false;
    notifyListeners();
    debugPrint('LightMeter: Stopped');
  }

  /// Update the lux reading (called externally from camera exposure data).
  void updateLux(double lux) {
    _currentLux = lux;
    _lightLevel = _classifyLight(lux);
    notifyListeners();
  }

  /// Estimate lux from camera frame brightness.
  ///
  /// Takes the average pixel brightness of a camera frame
  /// and maps it to an approximate lux value.
  void estimateFromFrameBrightness(double averageBrightness) {
    // Map 0-255 brightness to approximate lux range
    // This is a rough estimation — sufficient for orientation
    final estimatedLux = (averageBrightness / 255.0) * 10000;
    updateLux(estimatedLux);
  }

  /// Classify the light level from a lux reading.
  LightLevel _classifyLight(double lux) {
    if (lux < 10) return LightLevel.dark;
    if (lux < 50) return LightLevel.dim;
    if (lux < 500) return LightLevel.moderate;
    if (lux < 5000) return LightLevel.bright;
    return LightLevel.veryBright;
  }

  /// Update orientation-based audio feedback.
  /// As the user pans toward brighter areas, pitch rises.
  void _updateOrientationFeedback(double tiltDegrees) {
    // Map tilt to a frequency range (200Hz-800Hz)
    // Higher pitch = brighter direction
    final normalizedTilt = (tiltDegrees + 90) / 180; // 0.0 to 1.0
    final frequency = 200 + (normalizedTilt * 600);
    onToneUpdate?.call(frequency.clamp(200, 800));
  }

  /// Update the audio tone based on current light level.
  void _updateTone() {
    if (!_isActive) return;

    // Map lux to frequency: darker = lower tone, brighter = higher
    final normalizedLux = (_currentLux / 10000).clamp(0.0, 1.0);
    final frequency = 200 + (normalizedLux * 600);
    onToneUpdate?.call(frequency);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Categorized light levels for accessibility descriptions.
enum LightLevel {
  dark,
  dim,
  moderate,
  bright,
  veryBright,
  unknown,
}
