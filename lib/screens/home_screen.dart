import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart';
import '../services/platform_monitor.dart';
import '../core/theme.dart';
import '../services/gemini_live_service.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/ocr_service.dart';
import '../services/screen_navigator_service.dart';
import '../services/light_meter_service.dart';
import '../services/screen_capture_service.dart';
import '../services/clinical_telemetry_service.dart';
import '../services/sos_service.dart';
import '../services/barcode_service.dart';
import '../services/product_lookup_service.dart';
import '../services/user_memory_service.dart';

/// The main GozAI interface.
///
/// Designed for zero-friction, accessibility-first interaction:
/// - Large central activation button with pulse animation
/// - Mode switching via swipe or large buttons
/// - Minimal visual clutter
/// - Full TalkBack/VoiceOver compatibility
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _frameSubscription;
  StreamSubscription? _screenCaptureSubscription;
  StreamSubscription? _audioInputSubscription;
  StreamSubscription? _audioOutputSubscription;
  
  // OCR grounding: run offline OCR every N frames to give Gemini text context
  int _ocrFrameCounter = 0;
  static const int _ocrFrameInterval = 3; // Run OCR on every 3rd frame in Read mode
  
  // Clinical Telemetry: track how long patients can read before fatigue
  DateTime? _readingModeStartTime;

  // New Services
  final SosService _sosService = SosService();
  final BarcodeService _barcodeService = BarcodeService();
  final ProductLookupService _productLookupService = ProductLookupService();
  bool _isScanningBarcode = false;

  bool _showDebugCamera = false;

  // Idle check-in: if the user is silent for too long, Goz gently checks in
  Timer? _idleCheckInTimer;
  static const Duration _idleCheckInDuration = Duration(seconds: 90);

  // Edge cases: offline detection + battery monitoring
  bool _wasOffline = false;
  bool _lowBatteryWarned = false;
  late final PlatformMonitor _platformMonitor;

  // Debug Camera Window State
  Offset _debugCameraPosition = const Offset(20, 100);
  bool _debugCameraMinimized = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the central button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _platformMonitor = PlatformMonitor();

    // Wire up services after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeServices());
  }

  Future<void> _initializeServices() async {
    final cameraService = context.read<CameraService>();
    final geminiService = context.read<GeminiLiveService>();
    final audioService = context.read<AudioService>();
    final screenNav = context.read<ScreenNavigatorService>();
    final screenCapture = context.read<ScreenCaptureService>();

    // Initialize camera
    await cameraService.initialize();

    if (!mounted) return; // Prevent using context across async gaps

    // Edge case: monitor connectivity and battery (using platform monitor)
    _setupPlatformMonitoring();

    // Bind screen navigator to Gemini
    screenNav.bindGeminiService(geminiService);

    // Wire light meter audio tone feedback.
    // On web: plays a continuous oscillator that shifts frequency with light level.
    // On native: the tone is described aloud by Gemini when the user asks.
    final lightMeter = context.read<LightMeterService>();
    lightMeter.onToneUpdate = (frequency) {
      if (!kIsWeb) return; // Native: Gemini speech handles descriptions
      // Use Web Audio API for a live pitch-shifting tone
      _playLightMeterTone(frequency);
    };

    lightMeter.onProactiveDarknessWarning = () {
      debugPrint('GozAI: Proactive darkness warning triggered.');
      geminiService.sendText(
        '[SYSTEM - LOW LIGHT DETECTED] The ambient light level is near zero. The camera feed is likely too dark to see obstacles clearly. Proactively notify the user and ask if they would like you to turn on the flashlight.'
      );
    };

    // Feed camera frames to the light meter for offline luminance analysis
    cameraService.frameStream.listen((frameBytes) {
      if (lightMeter.isActive) {
        lightMeter.processFrameBrightness(frameBytes);
      }
    });

    // Bind Voice Command (Gemini Function Calling) intents
    geminiService.onSwitchCamera = () {
      cameraService.switchCamera();
      HapticService.tap();
    };
    geminiService.onSwitchMode = (mode) {
      // Telemetry: Log reading stamina if we are leaving reading mode
      if (geminiService.currentMode == GozAIMode.reading && mode != GozAIMode.reading) {
        if (_readingModeStartTime != null) {
          final duration = DateTime.now().difference(_readingModeStartTime!);
          context.read<ClinicalTelemetryService>().logReadingStamina(duration);
          _readingModeStartTime = null;
        }
      } else if (mode == GozAIMode.reading) {
        _readingModeStartTime = DateTime.now();
      }

      geminiService.switchMode(mode);
      HapticService.modeSwitch();
    };
    geminiService.onCaptureSnapshot = () {
      _captureSnapshot(geminiService);
    };
    geminiService.onDisconnect = () {
      _toggleSession(geminiService, audioService); // Safely turns off everything
    };
    geminiService.onTriggerHaptic = (pattern) {
      final telemetry = context.read<ClinicalTelemetryService>();
      switch (pattern) {
        case 'hazard':
          telemetry.logHazardDetected(pattern);
          HapticService.hazardWarning();
          break;
        case 'person':
          HapticService.personDetected();
          break;
        case 'navigate':
          HapticService.navigationCue();
          break;
        case 'safe':
          HapticService.safePathConfirm();
          break;
        case 'environment_mapped':
          HapticService.environmentKnown();
          break;
        case 'tap':
          HapticService.tap();
          break;
      }
    };

    // Wire SOS Caregiver Alert
    geminiService.onSendSosAlert = (message, severity, target) {
      _sosService.sendAlert(
        userId: 'demo_patient_001', // Target the authorized patient
        message: message,
        severity: severity,
        target: target,
      );
    };

    // Wire AI-synthesized UI taps (for UI Navigator mode)
    geminiService.onClickUiElement = (x, y) {
      // Inject a pointer event at the given coordinates.
      // In UI Nav mode, the screen is the camera — Gemini can click for the user.
      debugPrint('GozAI: AI synthesizing tap at ($x, $y)');
      
      final size = MediaQuery.of(context).size;
      // Coordinates from Gemini might be absolute (1080x1920 reference) or normalized (0-1).
      // Our prompt asks for absolute on a 1080x1920 canvas, so we scale them to the actual device.
      final dx = (x / 1080) * size.width;
      final dy = (y / 1920) * size.height;
      final position = Offset(dx.clamp(0.0, size.width), dy.clamp(0.0, size.height));

      debugPrint('GozAI: Scaled tap to device logical pixels: $position');

      // 1. Dispatch PointerDown
      GestureBinding.instance.handlePointerEvent(
        PointerDownEvent(
          pointer: 999, // Arbitrary pointer ID for synthetic events
          position: position,
          kind: PointerDeviceKind.touch,
        ),
      );

      // 2. Dispatch PointerUp immediately after
      Future.delayed(const Duration(milliseconds: 50), () {
        GestureBinding.instance.handlePointerEvent(
          PointerUpEvent(
            pointer: 999,
            position: position,
            kind: PointerDeviceKind.touch,
          ),
        );
      });
    };

    // Wire spatial context updates (for cognitive mapping)
    geminiService.onSpatialUpdate = (context_) {
      debugPrint('GozAI: Spatial context updated: $context_');
    };
    
    // Wire hardware flashlight control
    geminiService.onToggleFlashlight = (on) {
      final camera = context.read<CameraService>();
      camera.toggleFlashlight(on);
    };
    
    // True Interruption (Barge-in): instantly flush audio if Gemini detects user speech
    geminiService.onInterrupted = () {
      audioService.stopPlayback();
    };

    // Voice-activated video feed (Debug Camera)
    geminiService.onToggleDebugCamera = (visible) {
      debugPrint('GozAI: AI requested to toggle Debug Camera to: $visible');
      setState(() {
        _showDebugCamera = visible;
      });
      HapticService.alert();
    };

    // Voice-activated hidden transcripts
    geminiService.onOpenTranscripts = () {
      debugPrint('GozAI: AI requested to open transcripts.');
      HapticService.tap();
      if (mounted) context.push('/transcripts');
    };

    // Voice-activated High-Res OCR Analysis
    geminiService.onAnalyzeDocument = () async {
      debugPrint('GozAI: AI requested High-Res OCR scan.');
      HapticService.alert();
      
      final camera = context.read<CameraService>();
      final ocr = context.read<OcrService>();
      
      geminiService.sendText('[SYSTEM - INTERNAL] Taking high-resolution snapshot for OCR... please ask the user to hold the document steady for a moment.');
      
      final snapshotData = await camera.captureSnapshot();
      if (snapshotData == null) {
        geminiService.sendText('[SYSTEM - ERROR] Failed to capture snapshot. Inform the user.');
        return;
      }
      
      final result = await ocr.recognizeFromBytes(snapshotData);
      
      if (result.isEmpty) {
        geminiService.sendText('[SYSTEM - OCR RESULT] No text detected in the frame. Ask the user to adjust the document and try again.');
        return;
      }
      
      final isMed = ocr.isMedicationLabel(result) || ocr.isPrescriptionLabel(result);
      final isNut = ocr.isNutritionLabel(result);
      
      final groundingString = result.buildGroundingString(isMedication: isMed, isNutrition: isNut);
      
      // Inject to Gemini
      geminiService.sendText('[SYSTEM - OCR CAPTURE SUCCESSFUL]\\n$groundingString\\nPlease read this precisely to the user based on their question.');
      HapticService.safePathConfirm();
    };

    // Wire hardware re-initialization requests
    geminiService.onRequestHardwareAccess = (hardwareType, action) async {
      debugPrint('GozAI: Model requested hardware access for: $hardwareType action: $action');
      if (action == 'on') {
        if (hardwareType == 'camera') {
          final cameraService = context.read<CameraService>();
          await cameraService.initialize();
          if (cameraService.isInitialized && !cameraService.initFailed) {
            cameraService.startStreaming();
          }
        } else if (hardwareType == 'mic') {
          final audioSvc = context.read<AudioService>();
          await audioSvc.startRecording();
        }
      } else if (action == 'off') {
        if (hardwareType == 'camera') {
          context.read<CameraService>().stopStreaming();
        } else if (hardwareType == 'mic') {
          context.read<AudioService>().stopRecording();
        }
        _sosService.sendAlert(
          userId: 'demo_patient_001',
          message: 'User intentionally disabled their $hardwareType feed via voice command.',
          severity: 'info',
          target: 'caregiver',
        );
      }
      
      if (!mounted) return;

      // Send an updated hardware context to inform Gemini if the request succeeded
      setState(() {
         // UI will rebuild and chips will update
      });
      
      // Inject the current state back
      String hardwareContext = '[SYSTEM - HARDWARE CAPABILITIES UPDATE]\\n';
      if (context.read<AudioService>().isRecording) {
        hardwareContext += '- Microphone: ON\\n';
      } else {
        hardwareContext += '- Microphone: OFF (Disabled or failed)\\n';
      }
      
      final cam = context.read<CameraService>();
      if (cam.isInitialized && !cam.initFailed && cam.isStreaming) {
         hardwareContext += '- Camera: ON\\n';
      } else {
         hardwareContext += '- Camera: OFF/FAILED\\n';
      }
      geminiService.sendText(hardwareContext);
    };

    // Wire companion memory: Gemini can call rememberFact to persist user info
    geminiService.onRememberFact = (category, fact) {
      final memoryService = context.read<UserMemoryService>();
      memoryService.storeFact(
        userId: 'demo_patient_001',
        category: category,
        fact: fact,
      );
    };

    // Wire camera frames → Gemini (with OCR grounding in Read mode)
    _frameSubscription = cameraService.frameStream.listen((frame) {
      if (geminiService.currentMode == GozAIMode.uiNav) return; // UI nav uses screen frames
      
      geminiService.sendVideoFrame(frame);
      // In Read mode, run offline OCR every N frames and send extracted text
      // as grounding context so Gemini is anchored to actual on-screen characters.
      if (geminiService.currentMode == GozAIMode.reading) {
        // 1. Try barcode scan first for Universal Product Scanner pipeline
        if (!_isScanningBarcode) {
          _isScanningBarcode = true;
          _barcodeService.scanFromBytes(frame).then((barcode) async {
            if (barcode != null) {
              final product = await _productLookupService.lookup(barcode);
              if (product != null) {
                // Send injected context to Gemini
                geminiService.sendText(product.toGroundingString());
                HapticService.tap();
              }
            }
            _isScanningBarcode = false;
          });
        }

        // 2. Run OCR Grounding every N frames
        _ocrFrameCounter++;
        if (_ocrFrameCounter >= _ocrFrameInterval) {
          _ocrFrameCounter = 0;
          _runOcrGrounding(frame, geminiService);
        }
      } else {
        _ocrFrameCounter = 0; // Reset when not in reading mode
      }
    });

    // Reset idle timer whenever audio is being sent (user is talking)
    _audioInputSubscription = audioService.audioChunkStream.listen((_) {
      _resetIdleTimer();
    });

    // Wire internal UI frames → Gemini (For UI Navigator mode)
    _screenCaptureSubscription = screenCapture.frameStream.listen((frame) {
      if (geminiService.currentMode != GozAIMode.uiNav) return;
      geminiService.sendVideoFrame(frame); // Gemini sees the UI as the camera
    });

    // Wire audio input → Gemini
    _audioInputSubscription = audioService.audioChunkStream.listen((chunk) {
      geminiService.sendAudio(chunk);
    });

    // Wire Gemini audio output → speaker
    _audioOutputSubscription =
        geminiService.audioOutputStream.listen((audioData) {
      audioService.queueAudioResponse(audioData);
    });

    // Zero-UI Launch: Automatically start the session and open the mic upon app open
    if (!geminiService.isConnected && !audioService.isRecording) {
      debugPrint('GozAI: Auto-starting session for Zero-UI launch.');
      _toggleSession(geminiService, audioService);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _frameSubscription?.cancel();
    _screenCaptureSubscription?.cancel();
    _audioInputSubscription?.cancel();
    _audioOutputSubscription?.cancel();
    _idleCheckInTimer?.cancel();
    _platformMonitor.dispose();
    super.dispose();
  }

  /// Resets the idle check-in timer. Called every time audio is sent.
  void _resetIdleTimer() {
    _idleCheckInTimer?.cancel();
    _idleCheckInTimer = Timer(_idleCheckInDuration, _onIdleCheckIn);
  }

  /// Fired when the user has been silent for [_idleCheckInDuration].
  void _onIdleCheckIn() {
    if (!mounted) return;
    final gemini = context.read<GeminiLiveService>();
    if (!gemini.isConnected) return;
    gemini.sendText(
      '[SYSTEM - IDLE CHECK-IN]: The user has been silent for a while. '
      'Gently check in with a single short sentence. Do NOT be annoying — '
      'just a brief "Still here if you need me" or similar. '
      'If they do not respond after this, stay completely silent.'
    );
    debugPrint('GozAI: Idle check-in triggered after ${_idleCheckInDuration.inSeconds}s of silence.');
  }

  void _setupPlatformMonitoring() {
    _platformMonitor.setupConnectivityMonitoring(
      onOffline: () {
        _wasOffline = true;
        if (!mounted) return;
        final gemini = context.read<GeminiLiveService>();
        if (gemini.isConnected) {
          gemini.sendText(
            '[SYSTEM - CONNECTIVITY LOST]: The device has lost internet connection. '
            'Inform the user briefly that you may disconnect, but will reconnect when internet is back.'
          );
        }
      },
      onOnline: () {
        if (!_wasOffline) return;
        _wasOffline = false;
        if (!mounted) return;
        final gemini = context.read<GeminiLiveService>();
        if (gemini.isConnected) {
          gemini.sendText(
            '[SYSTEM - CONNECTIVITY RESTORED]: Internet connection is back. '
            'Briefly reassure the user that you are back online.'
          );
        }
      },
    );

    _platformMonitor.setupBatteryMonitoring(
      onLowBattery: (level, charging) {
        if (level <= 0.15 && !charging && !_lowBatteryWarned) {
          _lowBatteryWarned = true;
          if (!mounted) return;
          final gemini = context.read<GeminiLiveService>();
          if (gemini.isConnected) {
            final percent = (level * 100).round();
            gemini.sendText(
              '[SYSTEM - LOW BATTERY]: Device battery is at $percent%. '
              'Briefly warn the user that their battery is low and suggest charging '
              'to keep GozAI available for their safety.'
            );
          }
        } else if (level > 0.20) {
          _lowBatteryWarned = false; // Reset if battery recovers
        }
      },
    );
  }

  /// Handle physical volume button presses for hands-free control.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Volume Up = take snapshot and describe
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
        final gemini = context.read<GeminiLiveService>();
        _captureSnapshot(gemini);
        return KeyEventResult.handled;
      }
      // Volume Down = toggle mic
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
        final gemini = context.read<GeminiLiveService>();
        final audio = context.read<AudioService>();
        _toggleSession(gemini, audio);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: GozAITheme.backgroundBlack,
        extendBodyBehindAppBar: true, 
        appBar: _buildPremiumAppBar(context),
        body: Stack(
          children: [
            // Immersive ambient background layer
            _buildAmbientGlowBackground(),
            
            // Debug Camera Overlay (Floating Window)
            if (_showDebugCamera)
              _buildDebugCameraOverlay(context),
            
            // Debug Camera Toggle - Premium placement & contrast
            Positioned(
              top: 110,
              right: 24,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showDebugCamera = !_showDebugCamera;
                  });
                  HapticService.tap();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: GozAITheme.backgroundBlack.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: GozAITheme.accentCyan.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: GozAITheme.accentCyan.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showDebugCamera ? Icons.visibility_off : Icons.visibility,
                        color: GozAITheme.accentCyan,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showDebugCamera ? 'Hide Goz View' : 'Show Goz View',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // UI Layer
            SafeArea(
              child: Column(
                children: [
                  _buildStatusBar(),
                  const SizedBox(height: 8),
                  _buildHardwareStatusIndicators(),
                  const Spacer(flex: 1),
                  _buildCentralButton(),
                  const Spacer(flex: 2),
                  _buildModeSelector(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Premium Navigation Header for routing to specialized Dashboards.
  PreferredSizeWidget _buildPremiumAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent, // Let background shine under
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/logos/gozai_premium_lens_1772805910787.png',
            height: 32,
            semanticLabel: 'GozAI Premium Lens Logo',
          ),
          const SizedBox(width: 8),
          Text(
            'GozAI',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.monitor_heart_outlined),
          tooltip: 'Caregiver Dashboard',
          onPressed: () => context.push('/caregiver'),
        ),
        IconButton(
          icon: const Icon(Icons.medical_services_outlined),
          tooltip: 'Doctor Dashboard',
          onPressed: () => context.push('/doctor'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Status bar showing connection state and current mode with clean, subtle borders.
  Widget _buildStatusBar() {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: GozAITheme.surfacePure,
                  border: Border.all(color: GozAITheme.borderSubtle, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Semantics(
                  label: 'Status: ${gemini.statusMessage}. Mode: ${_modeName(gemini.currentMode)}',
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _connectionColor(gemini.connectionState),
                          boxShadow: [
                            BoxShadow(
                              color: _connectionColor(gemini.connectionState).withValues(alpha: 0.6),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          gemini.statusMessage,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: GozAITheme.primaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: GozAITheme.primaryBlue.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _modeName(gemini.currentMode),
                          style: TextStyle(
                            fontSize: 14,
                            color: GozAITheme.accentCyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Row of chips showing realtime Mic and Camera hardware states.
  Widget _buildHardwareStatusIndicators() {
    return Consumer3<GeminiLiveService, AudioService, CameraService>(
      builder: (context, gemini, audio, camera, _) {
        final isMicOn = audio.isRecording;
        final isCameraOn = camera.isInitialized && !camera.initFailed;
        String cameraText = 'Camera: Off';
        if (isCameraOn) {
          final dir = camera.currentLensDirection;
          if (dir == CameraLensDirection.front) {
            cameraText = 'Camera: Front';
          } else if (dir == CameraLensDirection.back) {
            cameraText = 'Camera: Rear';
          } else {
            cameraText = 'Camera: On';
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusChip(
                icon: isMicOn ? Icons.mic : Icons.mic_off,
                label: isMicOn ? 'Mic: On' : 'Mic: Off',
                isActive: isMicOn,
              ),
              const SizedBox(width: 12),
              _buildStatusChip(
                icon: isCameraOn ? Icons.videocam : Icons.videocam_off,
                label: cameraText,
                isActive: isCameraOn,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip({required IconData icon, required String label, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? GozAITheme.success.withValues(alpha: 0.1) : GozAITheme.hazardAlert.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? GozAITheme.success.withValues(alpha: 0.3) : GozAITheme.hazardAlert.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? GozAITheme.success : GozAITheme.hazardAlert),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Central activation button with high-end premium pulse glow.
  Widget _buildCentralButton() {
    return Consumer2<GeminiLiveService, AudioService>(
      builder: (context, gemini, audio, _) {
        final isActive = gemini.isConnected && audio.isRecording;
        final isSpeaking = gemini.isModelSpeaking;

        return GestureDetector(
          onTap: () => _toggleSession(gemini, audio),
          onLongPress: () => _captureSnapshot(gemini),
          child: Semantics(
            button: true,
            label: isActive
                ? 'GozAI is listening. Double-tap to stop.'
                : 'Start GozAI. Double-tap to activate.',
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = isActive ? _pulseAnimation.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          if (isSpeaking) ...[
                            GozAITheme.speakingPulse.withValues(alpha: 0.9),
                            GozAITheme.speakingPulse.withValues(alpha: 0.4),
                          ] else if (isActive) ...[
                            GozAITheme.listeningPulse.withValues(alpha: 0.9),
                            GozAITheme.listeningPulse.withValues(alpha: 0.4),
                          ] else ...[
                            GozAITheme.surfaceElevated,
                            GozAITheme.surfacePure,
                          ],
                        ],
                      ),
                      boxShadow: [
                        if (isActive || isSpeaking)
                          BoxShadow(
                            color: (isSpeaking ? GozAITheme.speakingPulse : GozAITheme.listeningPulse)
                                .withValues(alpha: 0.6),
                            blurRadius: 40,
                            spreadRadius: 15,
                          )
                        else
                          BoxShadow(
                            color: GozAITheme.primaryBlue.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                      ],
                      border: Border.all(
                        color: isActive ? Colors.transparent : GozAITheme.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isActive ? Icons.graphic_eq : Icons.power_settings_new_rounded,
                      size: 80,
                      color: isActive ? Colors.white : GozAITheme.textPrimary,
                      semanticLabel: isActive ? 'Listening' : 'Start',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Mode selector buttons utilizing high-contrast interaction guidelines.
  Widget _buildModeSelector() {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GozAITheme.surfacePure.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GozAITheme.borderSubtle, width: 1),
                ),
                child: Row(
                  children: [
                    _buildModeButton(gemini, GozAIMode.scene, Icons.wallpaper, 'Scene'),
                    const SizedBox(width: 4),
                    _buildModeButton(gemini, GozAIMode.reading, Icons.menu_book, 'Read'),
                    const SizedBox(width: 4),
                    _buildModeButton(gemini, GozAIMode.uiNav, Icons.touch_app, 'Screen'),
                    const SizedBox(width: 4),
                    _buildModeButton(gemini, GozAIMode.lightMeter, Icons.light_mode, 'Light'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeButton(
    GeminiLiveService gemini,
    GozAIMode mode,
    IconData icon,
    String label,
  ) {
    final isActive = gemini.currentMode == mode;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: '$label mode${isActive ? ", currently active" : ""}',
        child: InkWell(
          onTap: () {
            // Log spatial wandering if modes are cycled too fast
            context.read<ClinicalTelemetryService>().logSpatialDisorientation();

            // Telemetry: Log reading stamina if leaving
            if (gemini.currentMode == GozAIMode.reading && mode != GozAIMode.reading) {
              if (_readingModeStartTime != null) {
                final duration = DateTime.now().difference(_readingModeStartTime!);
                context.read<ClinicalTelemetryService>().logReadingStamina(duration);
                _readingModeStartTime = null;
              }
            } else if (mode == GozAIMode.reading && gemini.currentMode != GozAIMode.reading) {
              _readingModeStartTime = DateTime.now();
            }

            gemini.switchMode(mode);
            HapticService.modeSwitch();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isActive ? GozAITheme.primaryBlue.withValues(alpha: 0.25) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? GozAITheme.accentCyan.withValues(alpha: 0.5) : Colors.transparent,
                width: 1,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: GozAITheme.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: -2,
                )
              ] : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isActive ? Colors.white : GozAITheme.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : GozAITheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Actions ---

  Future<void> _toggleSession(
      GeminiLiveService gemini, AudioService audio) async {
    if (gemini.isConnected && audio.isRecording) {
      // Stop session
      await audio.stopRecording();
      if (!mounted) return;
      final cameraService = context.read<CameraService>();
      final screenCapture = context.read<ScreenCaptureService>();
      cameraService.stopStreaming();
      screenCapture.stopStreaming();
      // Stop light meter if active
      context.read<LightMeterService>().stop();
      await gemini.disconnect();
      HapticService.tap();
    } else {
      // Light meter mode is offline-only
      if (gemini.currentMode == GozAIMode.lightMeter) {
        final lightMeter = context.read<LightMeterService>();
        lightMeter.start();
        HapticService.connected();
        return;
      }

      // Start hardware first to verify permissions/state
      await audio.startRecording();
      if (!mounted) return;
      final cameraService = context.read<CameraService>();
      final screenCapture = context.read<ScreenCaptureService>();

      if (gemini.currentMode == GozAIMode.uiNav) {
        cameraService.stopStreaming();
        screenCapture.startStreaming();
      } else {
        screenCapture.stopStreaming();
        cameraService.startStreaming();
      }

      // Build definitive hardware truth state
      String hardwareContext = '';
      bool micMissing = !audio.isRecording;
      bool cameraMissing = !cameraService.isInitialized || cameraService.initFailed;

      if (micMissing || cameraMissing) {
        hardwareContext = '[SYSTEM - HARDWARE CAPABILITIES UPDATE]\n';
        if (micMissing) {
           hardwareContext += '- Microphone: OFF (Permission denied or hardware busy. Remind user supportively.)\n';
        }
        if (cameraMissing) {
           hardwareContext += '- Camera: OFF (I am blind. Remind user that enabling camera helps with safety.)\n';
        }
      }

      // Check for personalization: Do we know the user's name?
      final memoryService = context.read<UserMemoryService>();
      await memoryService.loadMemory('demo_patient_001');
      
      String? userName;
      try {
        final nameFact = memoryService.facts.firstWhere(
          (f) => f['category'] == 'person' && (f['fact'] as String).toLowerCase().contains('name is'),
        );
        final factText = nameFact['fact'] as String;
        // Extract name if pattern is "User's name is X" or similar
        final parts = factText.split(' is ');
        if (parts.length > 1) userName = parts.last.replaceAll('.', '').trim();
      } catch (_) {
        userName = null;
      }

      String launchContext;
      if (userName == null) {
        launchContext = '[SYSTEM - ONBOARDING]\nThis is a new user. Welcome them and ask for their name gracefully.';
      } else {
        launchContext = '[SYSTEM - AUTO-LAUNCH]\nWelcome $userName back to GozAI.';
      }

      // Build final context
      final memoryContext = memoryService.buildMemoryContext();
      String finalContext = '$launchContext\n\n$hardwareContext';
      if (memoryContext != null) {
        finalContext += '\n$memoryContext';
      }

      // Start Gemini streaming session
      await gemini.connect(hardwareContext: finalContext);

      // Start the idle check-in timer
      _resetIdleTimer();

      HapticService.connected();
    }
  }

  Future<void> _captureSnapshot(GeminiLiveService gemini) async {
    if (!gemini.isConnected) return;
    if (!mounted) return;
    final cameraService = context.read<CameraService>();
    final snapshot = await cameraService.captureSnapshot();
    if (snapshot != null) {
      gemini.sendVideoFrame(snapshot);
      gemini.sendText('Describe what you see in detail.');
      HapticService.tap();
    }
  }

  /// OCR Grounding for Read mode.
  ///
  /// Runs ML Kit offline OCR on a camera frame and sends the extracted
  /// text to Gemini as grounding context. This gives the Live API model a
  /// character-accurate anchor — preventing hallucination on text like
  /// medication dosages, expiry dates, and nutrition labels.
  Future<void> _runOcrGrounding(
    Uint8List frame,
    GeminiLiveService gemini,
  ) async {
    if (!gemini.isConnected || !mounted) return;
    final ocrService = context.read<OcrService>();
    final telemetry = context.read<ClinicalTelemetryService>();
    final lightMeter = context.read<LightMeterService>();
    
    try {
      final result = await ocrService.recognizeFromBytes(frame);
      if (result.isNotEmpty) {
        // Clinical Telemetry: Track contrast demand (how much light they needed)
        telemetry.logOcrAssist(lightMeter.currentLux, result.fullText.length);

        // Send OCR text as a silent system grounding prefix
        final isMed = ocrService.isMedicationLabel(result);
        final isNutr = ocrService.isNutritionLabel(result);
        final groundingString = result.buildGroundingString(
          isMedication: isMed, 
          isNutrition: isNutr,
        );
        
        gemini.sendText(
          '[OCR Context — do not read this aloud unless the user asks]: '
          'The following structured text was detected on camera with offline OCR. '
          'Use the bounding boxes to infer layout like columns or tables:\\n'
          '$groundingString',
        );
        debugPrint('OCR grounding sent: ${result.fullText.length} chars, isMed: $isMed, isNutr: $isNutr');
      }
    } catch (e) {
      debugPrint('OCR grounding error: $e');
    }
  }


  // --- Helpers ---

  String _modeName(GozAIMode mode) {
    switch (mode) {
      case GozAIMode.scene:
        return 'Scene';
      case GozAIMode.reading:
        return 'Read';
      case GozAIMode.uiNav:
        return 'Screen';
      case GozAIMode.lightMeter:
        return 'Light';
    }
  }

  Color _connectionColor(GeminiConnectionState state) {
    switch (state) {
      case GeminiConnectionState.connected:
        return GozAITheme.success;
      case GeminiConnectionState.connecting:
        return Colors.amber;
      case GeminiConnectionState.error:
        return GozAITheme.hazardAlert;
      case GeminiConnectionState.disconnected:
        return GozAITheme.textSecondary;
    }
  }

  /// Plays a brief pitched tone via Web Audio API for the light meter.
  ///
  /// Each 200ms tick from LightMeterService fires this, producing a
  /// pitch-shifted tone (200–800 Hz). Lower Hz = darker, higher Hz = brighter.
  /// Short duration (180ms) prevents tones from colliding into a continuous drone.
  void _playLightMeterTone(double frequency) {
    _platformMonitor.playTone(frequency, 0.18);
  }

  /// Immersive ambient glowing orbs that react to Gemini state
  Widget _buildAmbientGlowBackground() {
    return Consumer2<GeminiLiveService, AudioService>(
      builder: (context, gemini, audio, _) {
        final isActive = gemini.isConnected && audio.isRecording;
        final isSpeaking = gemini.isModelSpeaking;

        Color mainGlow;
        if (isSpeaking) {
          mainGlow = GozAITheme.speakingPulse;
        } else if (isActive) {
          mainGlow = GozAITheme.listeningPulse;
        } else {
          mainGlow = GozAITheme.primaryBlue;
        }

        return Stack(
          children: [
            // Top Right Orb
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOutSine,
              top: isActive ? 20 : -100,
              right: isActive ? -20 : -150,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1500),
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mainGlow.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: mainGlow.withValues(alpha: 0.2),
                      blurRadius: 120,
                      spreadRadius: 40,
                    )
                  ],
                ),
              ),
            ),
            // Bottom Left Orb
            AnimatedPositioned(
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOutSine,
              bottom: isSpeaking ? 0 : -80,
              left: isSpeaking ? -30 : -100,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 2000),
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GozAITheme.accentCyan.withValues(alpha: isSpeaking ? 0.2 : 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: GozAITheme.accentCyan.withValues(alpha: isSpeaking ? 0.2 : 0.05),
                      blurRadius: 100,
                      spreadRadius: 30,
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Floating Debug Camera window for absolute transparency of what Goz sees.
  Widget _buildDebugCameraOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double maxWidth = size.width * 0.45;
    final double maxHeight = size.height * 0.4;
    final double width = maxWidth.clamp(120.0, 240.0);
    final double expandedHeight = maxHeight.clamp(160.0, 320.0);
    final double minimizedHeight = 40.0; // Just the header

    // Ensure window stays within screen bounds
    double x = _debugCameraPosition.dx.clamp(0.0, size.width - width);
    double y = _debugCameraPosition.dy.clamp(0.0, size.height - (_debugCameraMinimized ? minimizedHeight : expandedHeight));

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _debugCameraPosition += details.delta;
          });
        },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: width,
                height: _debugCameraMinimized ? minimizedHeight : expandedHeight,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: GozAITheme.primaryBlue.withValues(alpha: 0.5), width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      // Header / Drag Handle
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: GozAITheme.surfaceElevated,
                          border: Border(bottom: BorderSide(color: GozAITheme.borderSubtle)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Goz View',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _debugCameraMinimized ? Icons.expand_more : Icons.expand_less,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _debugCameraMinimized = !_debugCameraMinimized;
                                    });
                                    HapticService.tap();
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _showDebugCamera = false;
                                    });
                                    HapticService.tap();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Camera Preview (Only visible when expanded)
                      if (!_debugCameraMinimized)
                        Expanded(
                          child: Consumer<CameraService>(
                            builder: (context, camera, _) {
                              if (!camera.isInitialized || camera.controller == null) {
                                return const Center(child: Icon(Icons.videocam_off, color: Colors.white24, size: 40));
                              }
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  AspectRatio(
                                    aspectRatio: camera.controller!.value.aspectRatio,
                                    child: CameraPreview(camera.controller!),
                                  ),
                                  // Small indicator showing it's a Live Feed
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'LIVE',
                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      );
  }
}

