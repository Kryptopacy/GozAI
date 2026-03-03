import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/app_config.dart';

/// Service for natively capturing the Flutter UI and streaming it to Gemini.
///
/// Used exclusively in [GozAIMode.uiNav] to avoid needing OS-level screen recording
/// permissions (AccessibilityService/ReplayKit). Requires the root app widget
/// to be wrapped in a [RepaintBoundary] using [globalKey].
class ScreenCaptureService extends ChangeNotifier {
  // The key attached to the root RepaintBoundary in main.dart
  final GlobalKey globalKey = GlobalKey();

  bool _isStreaming = false;
  Timer? _frameTimer;
  final double _fps = AppConfig.cameraFps;

  // Stream controller for JPEG UI frames
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  bool get isStreaming => _isStreaming;
  Stream<Uint8List> get frameStream => _frameController.stream;

  /// Start capturing the UI at the configured FPS.
  void startStreaming() {
    if (_isStreaming) return;

    _isStreaming = true;
    notifyListeners();

    final interval = Duration(milliseconds: (1000 / _fps).round());
    // Use a periodic timer to capture frames. Since capturing an image from a
    // render boundary is async, we don't await it strictly on the tick to avoid
    // blocking, but in practice 1 FPS is slow enough to not pile up.
    _frameTimer = Timer.periodic(interval, (_) => _captureFrame());

    debugPrint('ScreenCaptureService: UI Streaming started at $_fps FPS');
  }

  /// Stop capturing the UI.
  void stopStreaming() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _isStreaming = false;
    notifyListeners();
    debugPrint('ScreenCaptureService: UI Streaming stopped');
  }

  /// Captures the current rendering of the RepaintBoundary as a JPEG image.
  Future<void> _captureFrame() async {
    if (globalKey.currentContext == null) return;

    try {
      // Find the render object
      RenderRepaintBoundary boundary = globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      // Convert the boundary to a dart:ui Image
      // pixelRatio 1.0 is used to keep the byte size small for streaming.
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      
      // Convert the Image to JPEG bytes
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      // Note: `ImageByteFormat.png` is the standard cross-platform format supported 
      // out of the box by `toByteData`. Gemini accepts PNG just fine.
      if (byteData != null) {
        _frameController.add(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('ScreenCaptureService: Error capturing UI frame: $e');
    }
  }

  @override
  void dispose() {
    stopStreaming();
    _frameController.close();
    super.dispose();
  }
}
