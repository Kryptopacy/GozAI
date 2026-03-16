// Web-only audio bridge using the browser's Web Audio API + AudioWorklet for PCM extraction.
// Replaces the deprecated ScriptProcessorNode which was removed in modern Chrome.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// ---------------------------------------------------------------------------
// Minimal JS interop extensions needed for AudioWorkletNode + MessagePort
// ---------------------------------------------------------------------------

/// JS interop for the AudioWorklet addModule method.
extension AudioWorkletExt on web.AudioWorklet {
  external JSPromise<JSAny?> addModule(String moduleUrl);
}

/// JS interop for AudioWorkletNode constructor (not yet in package:web).
@JS('AudioWorkletNode')
external web.AudioWorkletNode _createAudioWorkletNode(
    web.AudioContext context, String name);

/// JS interop for MessagePort.onmessage setter.
extension MessagePortExt on web.MessagePort {
  external set onmessage(JSFunction? handler);
}

/// Extension type to safely access the worklet message payload {pcm16: ArrayBuffer}.
extension type _WorkletMessage._(JSObject _) implements JSObject {
  external JSArrayBuffer? get pcm16;
}

// ---------------------------------------------------------------------------
// Main Bridge class
// ---------------------------------------------------------------------------

/// Bridges the browser Web Audio API (via AudioWorklet) to Dart audio chunk streams,
/// explicitly converting the microphone stream to PCM 16-bit 16kHz.
class WebAudioBridge {
  static web.AudioContext? _audioContext;
  static web.MediaStreamAudioSourceNode? _sourceNode;
  static web.AudioWorkletNode? _workletNode;
  static web.MediaStream? _mediaStream;
  static void Function(Uint8List)? _onChunk;

  /// Start capturing audio from the browser microphone and converting to PCM16.
  static Future<bool> startRecording({
    required void Function(Uint8List chunk) onChunk,
  }) async {
    try {
      _onChunk = onChunk;

      // 1. Get raw MediaStream from the browser with echo cancellation
      _mediaStream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(
            audio: {
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
            }.jsify() as JSAny,
          ))
          .toDart;

      // 2. Setup an AudioContext targeting 16000 Hz
      final contextOptions = web.AudioContextOptions(sampleRate: 16000);
      _audioContext = web.AudioContext(contextOptions);

      // 3. Load the AudioWorklet processor module
      await AudioWorkletExt(_audioContext!.audioWorklet)
          .addModule('./audio_processor.js')
          .toDart;

      // 4. Create Source Node and Worklet Node
      _sourceNode = _audioContext!
          .createMediaStreamSource(_mediaStream as web.MediaStream);
      _workletNode =
          _createAudioWorkletNode(_audioContext!, 'pcm-capture-processor');

      // 5. Set onmessage callback on the worklet port — receives PCM16 ArrayBuffers
      _workletNode!.port.onmessage = _onWorkletMessage.toJS;

      // 6. Connect Mic -> Worklet (do NOT connect to destination — no audio feedback)
      _sourceNode!.connect(_workletNode!);

      debugPrint(
          'WebAudioBridge: AudioWorklet PCM16 recording started at ${_audioContext!.sampleRate} Hz');
      return true;
    } catch (e) {
      debugPrint('WebAudioBridge permission or setup error: $e');
      return false;
    }
  }

  /// Receives PCM16 ArrayBuffer messages from the AudioWorklet processor.
  static void _onWorkletMessage(web.MessageEvent event) {
    if (_onChunk == null) return;
    try {
      // The worklet posts { pcm16: ArrayBuffer }.
      // Cast via the typed extension type to access .pcm16 safely.
      final msg = event.data as _WorkletMessage;
      final pcm16Buffer = msg.pcm16;
      if (pcm16Buffer == null) return;
      final bytes = Uint8List.view(pcm16Buffer.toDart);
      _onChunk!(bytes);
    } catch (e) {
      debugPrint('WebAudioBridge: Error parsing worklet message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  /// Gapless Web Audio API Playback for PCM16 chunks (e.g. at 24000 Hz)
  static double _nextPlayTime = 0.0;
  static web.AudioContext? _playbackContext;

  static void playAudioChunk(Uint8List pcmData, int sampleRate) {
    if (_playbackContext == null) {
      _playbackContext =
          web.AudioContext(web.AudioContextOptions(sampleRate: sampleRate));
      _nextPlayTime = _playbackContext!.currentTime;
    }

    final int16List = Int16List.sublistView(pcmData);
    final float32List = Float32List(int16List.length);
    for (int i = 0; i < int16List.length; i++) {
      float32List[i] = int16List[i] / 32768.0;
    }

    final audioBuffer =
        _playbackContext!.createBuffer(1, float32List.length, sampleRate);
    audioBuffer.copyToChannel(float32List.toJS, 0);

    final source = _playbackContext!.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(_playbackContext!.destination);

    if (_nextPlayTime < _playbackContext!.currentTime) {
      _nextPlayTime = _playbackContext!.currentTime + 0.05;
    }

    source.start(_nextPlayTime);
    _nextPlayTime += audioBuffer.duration;
  }

  static void stopPlayback() {
    _nextPlayTime = 0.0;
    _playbackContext?.close();
    _playbackContext = null;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Stop capturing audio and clean up the audio graph.
  static void stopRecording() {
    // Remove the message listener
    _workletNode?.port.onmessage = null;

    _workletNode?.disconnect();
    _sourceNode?.disconnect();

    if (_mediaStream != null) {
      final tracks = _mediaStream!.getTracks().toDart;
      for (final track in tracks.whereType<web.MediaStreamTrack>()) {
        track.stop();
      }
    }

    _audioContext?.close();

    _workletNode = null;
    _sourceNode = null;
    _audioContext = null;
    _mediaStream = null;
    _onChunk = null;

    debugPrint('WebAudioBridge: Recording stopped and graph dismantled.');
  }
}
