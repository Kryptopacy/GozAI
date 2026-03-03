import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';

/// Service for managing camera capture and frame streaming.
///
/// Captures frames from the rear camera at configurable FPS and converts
/// them to JPEG format for streaming to Gemini Live API.
/// On web, camera initialization may require user permission via browser prompt.
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isStreaming = false;
  bool _initFailed = false;
  bool _isCapturing = false;
  Timer? _frameTimer;
  double _fps = AppConfig.cameraFps;

  // Stream controller for JPEG frames
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  // Public getters
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _isStreaming;
  bool get initFailed => _initFailed;
  CameraController? get controller => _controller;
  Stream<Uint8List> get frameStream => _frameController.stream;

  /// Initialize the camera (prefer rear camera).
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('CameraService: No cameras available');
        _initFailed = true;
        notifyListeners();
        return;
      }

      // On mobile we prefer the rear camera for scene analysis.
      // On web/PC, webcams often report as external, front, or unknown.
      CameraDescription camera;
      if (kIsWeb) {
        // On web just take the first available (usually the default webcam)
        camera = _cameras.first;
      } else {
        camera = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
      }

      // ImageFormatGroup.jpeg is NOT supported on Flutter web and causes
      // a CameraException(cameraNotReadable) hardware error. Omit it on web.
      // Furthermore, requesting ResolutionPreset.low or medium on Web often causes
      // cameraNotReadable because of rigid hardware constraints. Max allows negotiation.
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? ImageFormatGroup.unknown : ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _initFailed = false;
      notifyListeners();
      debugPrint('CameraService: Initialized with ${camera.name}');
    } catch (e) {
      debugPrint('CameraService: Initialization failed: $e');
      _initFailed = true;
      _controller = null;
      notifyListeners();
    }
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
    if (!isInitialized || !_isStreaming || _isCapturing) return;

    _isCapturing = true;
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      _frameController.add(bytes);
    } catch (e) {
      // Frame capture can fail intermittently, don't crash
      debugPrint('CameraService: Frame capture error: $e');
    } finally {
      _isCapturing = false;
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

    // Switch to the next available camera in the list
    final currentIndex = _cameras.indexWhere((c) => c.name == _controller?.description.name);
    final nextIndex = (currentIndex + 1) % _cameras.length;
    final newCamera = _cameras[nextIndex];

    final wasStreaming = _isStreaming;
    if (wasStreaming) stopStreaming();

    await _controller?.dispose();
    _controller = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: kIsWeb ? ImageFormatGroup.unknown : ImageFormatGroup.jpeg,
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
