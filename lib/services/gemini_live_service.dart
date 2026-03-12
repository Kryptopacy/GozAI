import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/app_config.dart';
import '../core/system_prompt.dart';

/// Connection state for the Gemini Live session.
enum GeminiConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Represents the current interaction mode.
enum GozAIMode {
  scene,    // Continuous scene monitoring
  reading,  // OCR / text reading
  uiNav,    // UI Navigator / digital accessibility
  lightMeter, // Offline light meter
}

/// The core service managing the WebSocket connection to Gemini Multimodal Live API.
///
/// Handles bidirectional streaming of audio + video frames and receiving
/// audio responses + function calls from Gemini.
class GeminiLiveService extends ChangeNotifier {
  WebSocketChannel? _channel;
  GeminiConnectionState _connectionState = GeminiConnectionState.disconnected;
  GozAIMode _currentMode = GozAIMode.scene;
  String _statusMessage = 'Tap to connect';
  bool _isModelSpeaking = false;
  
  // Spatial Context Buffer — grounding Gemini with a running mental map.
  // Research basis: Seiple W. et al., TVST 14(1):3, 2025 (PMC11721483) —
  // AI assistive tools significantly improve spatial orientation and ADL
  // completion for people with vision loss.
  final List<String> _spatialContextHistory = [];
  static const int _maxSpatialContextItems = 5;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Stream controllers for outbound data
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<Uint8List> _audioOutputController =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  // Callbacks for voice-activated intents (Gemini Function Calling)
  void Function()? onSwitchCamera;
  void Function(GozAIMode)? onSwitchMode;
  void Function()? onCaptureSnapshot;
  void Function()? onDisconnect;
  void Function(String pattern)? onTriggerHaptic;
  void Function(bool on)? onToggleFlashlight;
  void Function(String context)? onSpatialUpdate; // Callback for spatial memory
  void Function()? onInterrupted; // Callback for True Interruption (Barge-in)
  void Function(String hardwareType)? onRequestHardwareAccess;
  void Function(double x, double y)? onClickUiElement; // AI-synthesized UI taps
  void Function(String message, String severity)? onSendSosAlert; // Caregiver SOS
  void Function(bool visible)? onToggleDebugCamera; // Voice-activated video feed


  // Public getters
  GeminiConnectionState get connectionState => _connectionState;
  GozAIMode get currentMode => _currentMode;
  String get statusMessage => _statusMessage;
  bool get isModelSpeaking => _isModelSpeaking;
  bool get isConnected => _connectionState == GeminiConnectionState.connected;

  /// Stream of text transcripts from Gemini
  Stream<String> get transcriptStream => _transcriptController.stream;

  /// Stream of raw PCM audio data from Gemini
  Stream<Uint8List> get audioOutputStream => _audioOutputController.stream;

  /// Stream of status updates
  Stream<String> get statusStream => _statusController.stream;

  /// Connect to the Gemini Multimodal Live API via WebSocket.
  String? _pendingHardwareContext;

  Future<void> connect({String? hardwareContext}) async {
    _pendingHardwareContext = hardwareContext;
    if (_connectionState == GeminiConnectionState.connected ||
        _connectionState == GeminiConnectionState.connecting) {
      return;
    }

    _setConnectionState(GeminiConnectionState.connecting);
    _setStatus('Connecting to GozAI...');

    try {
      final wsUrl = AppConfig.geminiLiveWsUrl;
      debugPrint('GeminiLive: Connecting to $wsUrl');
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Wait for the WebSocket handshake to complete.
      // This throws if the handshake fails (e.g., 403 auth error).
      await _channel!.ready;

      _setConnectionState(GeminiConnectionState.connected);
      _setStatus('Connected');
      _reconnectAttempts = 0;

      // Send setup message with system prompt
      _sendSetupMessage();

      // Listen for incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('GeminiLive WebSocket error: $error (type: ${error.runtimeType})');
          _setConnectionState(GeminiConnectionState.error);
          _setStatus('Connection error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          final closeCode = _channel?.closeCode;
          final closeReason = _channel?.closeReason;
          debugPrint(
              'GeminiLive WebSocket closed. Code: $closeCode, Reason: $closeReason');
          _setConnectionState(GeminiConnectionState.disconnected);
          _setStatus('Disconnected (code: $closeCode)');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e, stack) {
      debugPrint('GeminiLive connection failed: $e');
      debugPrint('Stack: $stack');
      _setConnectionState(GeminiConnectionState.error);
      _setStatus('Failed to connect: $e');
      _scheduleReconnect();
    }
  }

  /// Attempt to reconnect using exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final backoff = Duration(seconds: 2 * _reconnectAttempts);
      debugPrint('GeminiLive: Reconnecting in ${backoff.inSeconds} seconds (Attempt $_reconnectAttempts/$_maxReconnectAttempts)...');
      _setStatus('Reconnecting in ${backoff.inSeconds}s...');
      
      Future.delayed(backoff, () {
        if (_connectionState == GeminiConnectionState.disconnected || 
            _connectionState == GeminiConnectionState.error) {
          connect();
        }
      });
    } else {
      _setStatus('Failed to reconnect after $_maxReconnectAttempts attempts');
    }
  }

  /// Disconnect from the Gemini Live API.
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _setConnectionState(GeminiConnectionState.disconnected);
    _setStatus('Disconnected');
  }

  /// Send the initial setup message with system instructions and config.
  void _sendSetupMessage() {
    final systemInstruction = _buildSystemPrompt();

    final setupMessage = {
      'setup': {
        'model': AppConfig.geminiModel,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': 'Aoede', // Clear, warm voice
              },
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'tools': [
          {
            'functionDeclarations': [
              {
                'name': 'switchCamera',
                'description': 'Switches or flips the user\'s camera (e.g., from front to back, or back to front). Call this when the user asks to switch the camera, flip the camera, or look at them.',
              },
              {
                'name': 'switchMode',
                'description': 'Switches the application mode (e.g., to scene, reading, screen, or light meter).',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'mode': {
                      'type': 'STRING',
                      'description': 'The mode to switch to. Must be one of: scene, reading, uiNav, lightMeter',
                      'enum': ['scene', 'reading', 'uiNav', 'lightMeter']
                    }
                  },
                  'required': ['mode']
                }
              },
              {
                'name': 'captureSnapshot',
                'description': 'Takes a high-resolution snapshot photo for detailed analysis. Call this when the user explicitly asks to take a picture, snap a photo, or look closely at something.',
              },
              {
                'name': 'disconnectSession',
                'description': 'Gracefully hangs up and ends the current GozAI session. Call this when the user says goodbye, stop listening, or asks you to turn off.',
              },
              {
                'name': 'triggerHaptic',
                'description': 'Triggers a haptic vibration pattern on the device to communicate urgency non-visually. Call this proactively when you POSITIVELY detect a hazard (pattern: hazard), a person approaching (pattern: person), a navigation cue (pattern: navigate), a clear path (pattern: safe), or when you map the environment (pattern: environment_mapped).',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'pattern': {
                      'type': 'STRING',
                      'description': 'The haptic pattern to trigger. Must be one of: hazard, person, navigate, safe, environment_mapped',
                      'enum': ['hazard', 'person', 'navigate', 'safe', 'environment_mapped']
                    }
                  },
                  'required': ['pattern']
                }
              },
              {
                'name': 'clickUiElement',
                'description': 'Taps a specific UI element on the screen in UI NAVIGATOR mode. Use the x and y coordinates of the element you see in the screenshot. Coordinates should be relative to a standard 1080x1920 logical screen, though the relative position is most important.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'x': {
                      'type': 'INTEGER',
                      'description': 'The X coordinate of the element to tap',
                    },
                    'y': {
                      'type': 'INTEGER',
                      'description': 'The Y coordinate of the element to tap',
                    },
                  },
                  'required': ['x', 'y'],
                }
              },
              {
                'name': 'toggleFlashlight',
                'description': 'Turns the device\'s hardware LED flashlight on or off. Use this autonomously if the camera feed is completely black and you cannot see, OR if the user explicitly asks you to turn on the light.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'on': {
                      'type': 'BOOLEAN',
                      'description': 'True to turn the flashlight ON. False to turn it OFF.',
                    }
                  },
                  'required': ['on'],
                }
              },
              {
                'name': 'requestHardwareAccess',
                'description': 'Requests the app to re-initialize or ask for hardware permissions (camera or mic). Call this if the system context says a sensor is OFF, the user asks you to perform a task requiring that sensor, and you have explained to them that you need to turn it on.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'hardwareType': {
                      'type': 'STRING',
                      'description': 'The hardware to request: "camera" or "mic".',
                      'enum': ['camera', 'mic'],
                    }
                  },
                  'required': ['hardwareType'],
                }
              },
              {
                'name': 'updateSpatialContext',
                'description': 'Stores a key landmark or spatial description in your running mental map of the user\'s environment. Call this when the user enters a new room, passes a major landmark (e.g., stairs, checkout counter, exit), or when the environment changes significantly.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'description': {
                      'type': 'STRING',
                      'description': 'A concise description of the spatial layout or landmark, relative to the user. (e.g., "Entrance is 10 feet behind you.")',
                    }
                  },
                  'required': ['description'],
                }
              },
              {
                'name': 'sendSosAlert',
                'description': 'Sends an emergency SOS alert to the user\'s designated caregiver via Firestore. Call this IMMEDIATELY if the user says they need help, are lost, feel unsafe, say "emergency", or if their speech sounds panicked or distressed. Do NOT ask for confirmation — act immediately.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'message': {
                      'type': 'STRING',
                      'description': 'A brief, clear description of the situation to send to the caregiver. E.g., "User says they are lost and scared."',
                    },
                    'severity': {
                      'type': 'STRING',
                      'description': 'Severity of the alert. Use "mild" for confusion/lost. Use "critical" for danger/injury.',
                      'enum': ['mild', 'critical'],
                    },
                  },
                  'required': ['message', 'severity'],
                }
              },
              {
                'name': 'toggleDebugCamera',
                'description': 'Toggles the visibility of the internal debug camera video feed window on the user\'s screen. Call this when the user asks to see what I see, open the video feed, hide the camera, or show the debug window.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'visible': {
                      'type': 'BOOLEAN',
                      'description': 'True to show the video feed, False to hide it.',
                    }
                  },
                  'required': ['visible'],
                }
              }
            ]
          }
        ],
      },
    };

    _sendJson(setupMessage);
    debugPrint('GeminiLive setup sent with mode: ${_currentMode.name}');
  }

  /// Build the system prompt based on current mode.
  String _buildSystemPrompt() {
    String prompt = GozAISystemPrompt.persona;

    switch (_currentMode) {
      case GozAIMode.scene:
        prompt += '\n\n${GozAISystemPrompt.sceneModeAddendum}';
        break;
      case GozAIMode.reading:
        prompt += '\n\n${GozAISystemPrompt.readingModeAddendum}';
        break;
      case GozAIMode.uiNav:
        prompt += '\n\n${GozAISystemPrompt.uiNavigatorAddendum}';
        break;
      case GozAIMode.lightMeter:
        // Light meter is offline, no Gemini needed for this mode
        break;
    }

    return prompt;
  }

  /// Send raw audio data (PCM 16-bit mono 16kHz) to Gemini.
  void sendAudio(Uint8List pcmData) {
    if (!isConnected) return;

    final base64Audio = base64Encode(pcmData);
    final message = {
      'realtimeInput': {
        'mediaChunks': [
          {
            'mimeType': 'audio/pcm;rate=${AppConfig.audioInputSampleRate}',
            'data': base64Audio,
          },
        ],
      },
    };

    _sendJson(message);
  }

  /// Send a camera frame (JPEG bytes) to Gemini for scene analysis.
  void sendVideoFrame(Uint8List jpegData) {
    if (!isConnected) return;

    final base64Image = base64Encode(jpegData);
    final message = {
      'realtimeInput': {
        'mediaChunks': [
          {
            'mimeType': 'image/jpeg',
            'data': base64Image,
          },
        ],
      },
    };

    _sendJson(message);
  }

  /// Send a text message to Gemini (for typed input or mode commands).
  void sendText(String text) {
    if (!isConnected) return;

    final message = {
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'turnComplete': true,
      },
    };

    _sendJson(message);
  }

  /// Switch the current mode and reconnect with updated system prompt.
  Future<void> switchMode(GozAIMode mode) async {
    if (_currentMode == mode) return;
    _currentMode = mode;
    notifyListeners();

    // Reconnect with new system prompt
    if (isConnected) {
      await disconnect();
      await connect();
    }
  }

  /// Handle incoming WebSocket messages from Gemini.
  void _handleMessage(dynamic message) {
    try {
      String messageStr;
      if (message is String) {
        messageStr = message;
      } else if (message is List<int>) {
        messageStr = utf8.decode(message);
      } else {
        debugPrint('GeminiLive: Unknown message type: ${message.runtimeType}');
        return;
      }
      
      final data = jsonDecode(messageStr) as Map<String, dynamic>;
      // Handle setup complete
      if (data.containsKey('setupComplete')) {
        debugPrint('GeminiLive setup complete');
        _setStatus('Ready');
        
        // Inject hardware context if provided
        if (_pendingHardwareContext != null) {
          debugPrint('GeminiLive: Injecting hardware context state.');
          sendText(_pendingHardwareContext!);
          _pendingHardwareContext = null;
        }
        
        return;
      }

      // Handle server content (audio response, text, etc.)
      if (data.containsKey('serverContent')) {
        final serverContent = data['serverContent'] as Map<String, dynamic>;

        // Check if model turn is complete
        if (serverContent['turnComplete'] == true) {
          _isModelSpeaking = false;
          notifyListeners();
          return;
        }

        // Check if this is an interruption acknowledgment
        if (serverContent['interrupted'] == true) {
          debugPrint('GeminiLive: Server acknowledged interruption.');
          _isModelSpeaking = false;
          onInterrupted?.call(); // Instantly fire barge-in callback
          notifyListeners();
          return;
        }

        // Process model turn parts
        final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
        if (modelTurn != null) {
          final parts = modelTurn['parts'] as List<dynamic>?;
          if (parts != null) {
            for (final part in parts) {
              final partMap = part as Map<String, dynamic>;

              // Text response — log only, do not surface to UI.
              // The model's text track contains chain-of-thought reasoning
              // which is meaningless to a blind user. All information is
              // delivered via audio. Keeping this in logs for debugging.
              if (partMap.containsKey('text')) {
                final text = partMap['text'] as String;
                debugPrint('GeminiLive [text]: $text');
                // Intentionally NOT pushed to _transcriptController
              }

              // Audio response (inline data)
              if (partMap.containsKey('inlineData')) {
                _isModelSpeaking = true;
                notifyListeners();

                final inlineData =
                    partMap['inlineData'] as Map<String, dynamic>;
                final audioBase64 = inlineData['data'] as String;
                final audioBytes = base64Decode(audioBase64);
                _audioOutputController.add(Uint8List.fromList(audioBytes));
              }
            }
          }
        }
      }

      // Handle tool calls (for ADK backend integration)
      if (data.containsKey('toolCall')) {
        _handleToolCall(data['toolCall'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('GeminiLive message parse error: $e');
    }
  }

  /// Handle tool calls from Gemini (intent routing to Local App Actions or ADK backend).
  void _handleToolCall(Map<String, dynamic> toolCall) {
    if (!toolCall.containsKey('functionCalls')) return;
    final functionCalls = toolCall['functionCalls'] as List<dynamic>;
    
    final functionResponses = [];

    for (final call in functionCalls) {
      final functionCallMap = call as Map<String, dynamic>;
      final callId = functionCallMap['id'] as String;
      final name = functionCallMap['name'] as String;
      final args = functionCallMap['args'] as Map<String, dynamic>? ?? {};

      debugPrint('GeminiLive: Executing tool call: $name');

      bool success = true;
      try {
        switch (name) {
          case 'switchCamera':
            onSwitchCamera?.call();
            break;
          case 'switchMode':
            final modeStr = args['mode'] as String?;
            final newMode = GozAIMode.values.firstWhere(
              (e) => e.name == modeStr,
              orElse: () => _currentMode,
            );
            onSwitchMode?.call(newMode);
            break;
          case 'captureSnapshot':
            onCaptureSnapshot?.call();
            break;
          case 'disconnectSession':
            onDisconnect?.call();
            break;
          case 'triggerHaptic':
            final pattern = args['pattern'] as String? ?? 'navigate';
            onTriggerHaptic?.call(pattern);
            break;
          case 'updateSpatialContext':
            final desc = args['description'] as String?;
            if (desc != null && desc.isNotEmpty) {
               _spatialContextHistory.add(desc);
               if (_spatialContextHistory.length > _maxSpatialContextItems) {
                 _spatialContextHistory.removeAt(0);
               }
               onSpatialUpdate?.call(desc);
               debugPrint('GeminiLive: Spatial Context Updated -> \$desc');
            }
            break;
          case 'clickUiElement':
            final x = (args['x'] as num?)?.toDouble() ?? 0.0;
            final y = (args['y'] as num?)?.toDouble() ?? 0.0;
            // Route UI tap through the registered callback (wired up in home_screen)
            // and provide haptic feedback so the user knows a tap was synthesized.
            onClickUiElement?.call(x, y);
            onTriggerHaptic?.call('tap');
            break;
          case 'sendSosAlert':
            final message = args['message'] as String? ?? 'User needs help.';
            final severity = args['severity'] as String? ?? 'mild';
            onSendSosAlert?.call(message, severity);
            // Trigger urgent haptic pattern immediately so user feels the action
            onTriggerHaptic?.call('hazard');
            debugPrint('GeminiLive: SOS alert fired — severity: $severity, message: $message');
            break;
          case 'toggleFlashlight':
            final on = args['on'] as bool? ?? false;
            onToggleFlashlight?.call(on);
            break;
          case 'requestHardwareAccess':
            final hardwareType = args['hardwareType'] as String? ?? 'camera';
            onRequestHardwareAccess?.call(hardwareType);
            break;
          case 'toggleDebugCamera':
            final visible = args['visible'] as bool? ?? false;
            onToggleDebugCamera?.call(visible);
            break;
          default:
            debugPrint('GeminiLive: Unknown tool call $name');
            success = false;
        }
      } catch (e) {
        debugPrint('GeminiLive: Error executing tool call $name: $e');
        success = false;
      }

      functionResponses.add({
        'id': callId,
        'name': name,
        'response': {
          'result': success ? 'Success' : 'Failed to execute tool',
        }
      });
    }

    // Send the tool execution results back to Gemini so it can resume speaking
    if (functionResponses.isNotEmpty) {
      _sendJson({
        'toolResponse': {
          'functionResponses': functionResponses,
        }
      });
    }
  }

  /// Send a JSON message over the WebSocket.
  /// Guards against sending on a closed/closing socket to avoid
  /// "WebSocket is already in CLOSING or CLOSED state" errors.
  void _sendJson(Map<String, dynamic> message) {
    if (_channel == null || !isConnected) return;
    _channel!.sink.add(jsonEncode(message));
  }

  /// Update connection state and notify listeners.
  void _setConnectionState(GeminiConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  /// Update status message and notify listeners.
  void _setStatus(String status) {
    _statusMessage = status;
    _statusController.add(status);
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _transcriptController.close();
    _audioOutputController.close();
    _statusController.close();
    super.dispose();
  }
}
