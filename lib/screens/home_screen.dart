import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../services/gemini_live_service.dart';
import '../services/camera_service.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/screen_navigator_service.dart';
import '../services/light_meter_service.dart';

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
  StreamSubscription? _audioInputSubscription;
  StreamSubscription? _audioOutputSubscription;

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

    // Wire up services after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeServices());
  }

  Future<void> _initializeServices() async {
    final cameraService = context.read<CameraService>();
    final geminiService = context.read<GeminiLiveService>();
    final audioService = context.read<AudioService>();
    final screenNav = context.read<ScreenNavigatorService>();

    // Initialize camera
    await cameraService.initialize();

    // Bind screen navigator to Gemini
    screenNav.bindGeminiService(geminiService);

    // Bind Voice Command (Gemini Function Calling) intents
    geminiService.onSwitchCamera = () {
      cameraService.switchCamera();
      HapticService.tap();
    };
    geminiService.onSwitchMode = (mode) {
      geminiService.switchMode(mode);
      HapticService.modeSwitch();
    };
    geminiService.onCaptureSnapshot = () {
      _captureSnapshot(geminiService);
    };
    geminiService.onDisconnect = () {
      _toggleSession(geminiService, audioService); // Safely turns off everything
    };

    // Wire camera frames → Gemini
    _frameSubscription = cameraService.frameStream.listen((frame) {
      geminiService.sendVideoFrame(frame);
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _frameSubscription?.cancel();
    _audioInputSubscription?.cancel();
    _audioOutputSubscription?.cancel();
    super.dispose();
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
        appBar: _buildPremiumAppBar(context),
        body: SafeArea(
          child: Column(
            children: [
              _buildStatusBar(),
              const Spacer(flex: 1),
              _buildCentralButton(),
              const Spacer(flex: 2),
              _buildModeSelector(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Premium Navigation Header for routing to specialized Dashboards.
  PreferredSizeWidget _buildPremiumAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.remove_red_eye_outlined, color: GozAITheme.primaryBlue, size: 24),
          const SizedBox(width: 8),
          Text(
            'GozAI',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: GozAITheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GozAITheme.borderSubtle, width: 1),
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
                        color: _connectionColor(gemini.connectionState).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    gemini.statusMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: GozAITheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GozAITheme.primaryBlue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _modeName(gemini.currentMode),
                    style: const TextStyle(
                      fontSize: 14,
                      color: GozAITheme.accentCyan,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  /// Mode selector buttons utilizing Vercel's interaction and contrast guidelines.
  Widget _buildModeSelector() {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildModeButton(gemini, GozAIMode.scene, Icons.wallpaper, 'Scene'),
              const SizedBox(width: 8),
              _buildModeButton(gemini, GozAIMode.reading, Icons.menu_book, 'Read'),
              const SizedBox(width: 8),
              _buildModeButton(gemini, GozAIMode.uiNav, Icons.touch_app, 'Screen'),
              const SizedBox(width: 8),
              _buildModeButton(gemini, GozAIMode.lightMeter, Icons.light_mode, 'Light'),
            ],
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
            gemini.switchMode(mode);
            HapticService.modeSwitch();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isActive ? GozAITheme.primaryBlue.withValues(alpha: 0.15) : GozAITheme.surfacePure,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? GozAITheme.primaryBlue : GozAITheme.borderSubtle,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isActive ? GozAITheme.accentCyan : GozAITheme.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? GozAITheme.textPrimary : GozAITheme.textSecondary,
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
      cameraService.stopStreaming();
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

      // Start Gemini streaming session
      await gemini.connect();
      await audio.startRecording();
      if (!mounted) return;
      final cameraService = context.read<CameraService>();
      cameraService.startStreaming();
      
      if (cameraService.initFailed || !cameraService.isInitialized) {
        // Force the model into strict blind mode since the camera threw an exception (e.g. privacy shutter)
        gemini.sendText(
          'System Notification: The user camera is hardware-disabled or blocked by a privacy shutter. '
          'You are completely blind and CANNOT see the environment. '
          'Do NOT attempt to describe the user\'s surroundings or assume they are safe. '
          'Acknowledge this limitation immediately.'
        );
      }

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
}
