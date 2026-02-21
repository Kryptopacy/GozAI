import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  StreamSubscription? _transcriptSubscription;

  String _lastTranscript = '';
  final List<String> _conversationLog = [];

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

    // Wire Gemini text transcript → UI
    _transcriptSubscription =
        geminiService.transcriptStream.listen((transcript) {
      setState(() {
        _lastTranscript = transcript;
        _conversationLog.add(transcript);
        if (_conversationLog.length > 50) _conversationLog.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _frameSubscription?.cancel();
    _audioInputSubscription?.cancel();
    _audioOutputSubscription?.cancel();
    _transcriptSubscription?.cancel();
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
        backgroundColor: GozAITheme.surfaceDark,
        body: SafeArea(
          child: Column(
            children: [
              _buildStatusBar(),
              const Spacer(flex: 1),
              _buildCentralButton(),
              const SizedBox(height: 24),
              _buildTranscriptArea(),
              const Spacer(flex: 1),
              _buildModeSelector(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Status bar showing connection state and current mode.
  Widget _buildStatusBar() {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        return Semantics(
          label:
              'Status: ${gemini.statusMessage}. Mode: ${_modeName(gemini.currentMode)}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                // Connection indicator
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connectionColor(gemini.connectionState),
                    boxShadow: [
                      BoxShadow(
                        color: _connectionColor(gemini.connectionState)
                            .withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Status text
                Expanded(
                  child: Text(
                    gemini.statusMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                // Mode badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: GozAITheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: GozAITheme.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _modeName(gemini.currentMode),
                    style: const TextStyle(
                      fontSize: 16,
                      color: GozAITheme.primaryLight,
                      fontWeight: FontWeight.w600,
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

  /// Central activation button with pulse animation.
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
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          if (isSpeaking) ...[
                            GozAITheme.speakingPulse.withValues(alpha: 0.8),
                            GozAITheme.speakingPulse.withValues(alpha: 0.3),
                          ] else if (isActive) ...[
                            GozAITheme.listeningPulse.withValues(alpha: 0.8),
                            GozAITheme.listeningPulse.withValues(alpha: 0.3),
                          ] else ...[
                            GozAITheme.surfaceElevated,
                            GozAITheme.surfaceCard,
                          ],
                        ],
                      ),
                      boxShadow: [
                        if (isActive)
                          BoxShadow(
                            color: (isSpeaking
                                    ? GozAITheme.speakingPulse
                                    : GozAITheme.listeningPulse)
                                .withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                      ],
                    ),
                    child: Icon(
                      isActive ? Icons.hearing : Icons.visibility,
                      size: 80,
                      color: Colors.white,
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

  /// Transcript display area showing recent AI responses.
  Widget _buildTranscriptArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GozAITheme.primaryBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Semantics(
        liveRegion: true,
        label: _lastTranscript.isEmpty
            ? 'No transcript yet'
            : 'GozAI says: $_lastTranscript',
        child: SingleChildScrollView(
          reverse: true,
          child: Text(
            _lastTranscript.isEmpty
                ? 'Tap the button to start GozAI'
                : _lastTranscript,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// Mode selector — large, accessible buttons for switching modes.
  Widget _buildModeSelector() {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildModeButton(
                gemini,
                GozAIMode.scene,
                Icons.remove_red_eye,
                'Scene',
              ),
              const SizedBox(width: 8),
              _buildModeButton(
                gemini,
                GozAIMode.reading,
                Icons.menu_book,
                'Read',
              ),
              const SizedBox(width: 8),
              _buildModeButton(
                gemini,
                GozAIMode.uiNav,
                Icons.phone_android,
                'Screen',
              ),
              const SizedBox(width: 8),
              _buildModeButton(
                gemini,
                GozAIMode.lightMeter,
                Icons.light_mode,
                'Light',
              ),
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
        child: GestureDetector(
          onTap: () {
            gemini.switchMode(mode);
            HapticService.modeSwitch();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isActive
                  ? GozAITheme.primaryBlue.withValues(alpha: 0.2)
                  : GozAITheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? GozAITheme.primaryBlue
                    : GozAITheme.surfaceElevated,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color:
                      isActive ? GozAITheme.primaryBlue : GozAITheme.textSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? GozAITheme.primaryBlue
                        : GozAITheme.textSecondary,
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
        setState(() {
          _lastTranscript = lightMeter.lightDescription;
        });
        return;
      }

      // Start Gemini streaming session
      await gemini.connect();
      await audio.startRecording();
      if (!mounted) return;
      final cameraService = context.read<CameraService>();
      cameraService.startStreaming();
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
        return GozAITheme.warning;
      case GeminiConnectionState.error:
        return GozAITheme.danger;
      case GeminiConnectionState.disconnected:
        return GozAITheme.textSecondary;
    }
  }
}
