import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';

/// Service for managing camera capture and frame streaming.
///
/// Captures frames from the rear camera at configurable FPS and converts
/// them to JPEG format for streaming to Gemini Live API.
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isStreaming = false;
  Timer? _frameTimer;
  double _fps = AppConfig.cameraFps;

  // Stream controller for JPEG frames
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  // Public getters
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _isStreaming;
  CameraController? get controller => _controller;
  Stream<Uint8List> get frameStream => _frameController.stream;

  /// Initialize the camera (prefer rear camera).
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      debugPrint('CameraService: No cameras available');
      return;
    }

    // Prefer rear camera for scene analysis
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // Balance quality vs. bandwidth
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    notifyListeners();
    debugPrint('CameraService: Initialized with ${camera.name}');
  }

  /// Start continuous frame streaming at configured FPS.
  void startStreaming() {
    if (!isInitialized || _isStreaming) return;

    _isStreaming = true;
    notifyListeners();

    final interval = Duration(milliseconds: (1000 / _fps).round());
    _frameTimer = Timer.periodic(interval, (_) => _captureFrame());

    debugPrint('CameraService: Streaming at $_fps FPS');
  }

  /// Stop continuous frame streaming.
  void stopStreaming() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _isStreaming = false;
    notifyListeners();
    debugPrint('CameraService: Streaming stopped');
  }

  /// Capture a single snapshot (for Volume Up trigger or on-demand).
  Future<Uint8List?> captureSnapshot() async {
    if (!isInitialized) return null;

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      debugPrint('CameraService: Snapshot captured (${bytes.length} bytes)');
      return bytes;
    } catch (e) {
      debugPrint('CameraService: Snapshot failed: $e');
      return null;
    }
  }

  /// Capture a frame and emit it to the stream.
  Future<void> _captureFrame() async {
    if (!isInitialized || !_isStreaming) return;

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      _frameController.add(bytes);
    } catch (e) {
      // Frame capture can fail intermittently, don't crash
      debugPrint('CameraService: Frame capture error: $e');
    }
  }

  /// Update the streaming FPS.
  void setFps(double fps) {
    _fps = fps;
    if (_isStreaming) {
      stopStreaming();
      startStreaming();
    }
  }

  /// Switch between front and rear cameras.
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    final currentDirection = _controller?.description.lensDirection;
    final newCamera = _cameras.firstWhere(
      (c) => c.lensDirection != currentDirection,
      orElse: () => _cameras.first,
    );

    final wasStreaming = _isStreaming;
    if (wasStreaming) stopStreaming();

    await _controller?.dispose();
    _controller = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    notifyListeners();

    if (wasStreaming) startStreaming();
  }

  @override
  void dispose() {
    stopStreaming();
    _controller?.dispose();
    _frameController.close();
    super.dispose();
  }
}
