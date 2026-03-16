import 'package:flutter/foundation.dart';
import 'platform_monitor_stub.dart' if (kIsWeb) 'platform_monitor_web.dart';

abstract class PlatformMonitor {
  factory PlatformMonitor() => getPlatformMonitor();

  void setupConnectivityMonitoring({
    required VoidCallback onOffline,
    required VoidCallback onOnline,
  });

  void setupBatteryMonitoring({
    required Function(double level, bool charging) onLowBattery,
  });

  /// Play a pitched tone (e.g. for light meter).
  void playTone(double frequency, double durationSeconds);

  void dispose();
}
