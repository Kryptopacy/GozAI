// Web-only audio bridge using the browser's Web Audio API for PCM extraction.
// Imported by audio_service.dart on web via conditional import.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:web/web.dart' as web;

/// Bridges the browser Web Audio API to Dart audio chunk streams
/// explicitly converting the microphone stream to PCM 16-bit 16kHz.
class WebAudioBridge {
  static web.AudioContext? _audioContext;
  static web.MediaStreamAudioSourceNode? _sourceNode;
  static web.ScriptProcessorNode? _processorNode;
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
            }.jsify() as JSAny, // cast explicitly to JSAny
          ))
          .toDart;

      // 2. Setup an AudioContext specifically targeting 16000 Hz if possible
      final contextOptions = web.AudioContextOptions(sampleRate: 16000);
      _audioContext = web.AudioContext(contextOptions);

      // 3. Create a Source Node from the mic stream
      _sourceNode = _audioContext!.createMediaStreamSource(_mediaStream as web.MediaStream);

      // 4. Create a ScriptProcessor to intercept raw PCM float data
      _processorNode = _audioContext!.createScriptProcessor(4096, 1, 1);

      // 5. Setup the audio processing callback
      _processorNode!.addEventListener('audioprocess', _handleAudioProcess.toJS);

      // 6. Connect Mic -> Processor. Do NOT connect processor to destination to avoid feedback loops!
      _sourceNode!.connect(_processorNode!);
      // Note: Modern browsers don't strict-require destination connection for audioprocess to fire.
      // If needed in the future, we can connect it but zero-out the outputBuffer.
      // _processorNode!.connect(_audioContext!.destination); 

      debugPrint('WebAudioBridge: PCM16 Recording started at ${_audioContext!.sampleRate} Hz');
      return true;
    } catch (e) {
      debugPrint('WebAudioBridge permission or setup error: $e');
      return false;
    }
  }

  // Intercepts the Float32 audio buffers from the browser, converts to 16-bit PCM.
  static void _handleAudioProcess(web.Event event) {
    if (_onChunk == null) return;

    final audioEvent = event as web.AudioProcessingEvent;
    final inputBuffer = audioEvent.inputBuffer;
    
    // Get the first channel (mono) Float32Array bounds [-1.0 to 1.0]
    final float32JsArray = inputBuffer.getChannelData(0);
    
    // Safely cast JSFloat32Array to Dart's Float32List
    final float32Data = float32JsArray.toDart;
    
    // Convert Float32 to Int16 (PCM 16-bit)
    final pcm16Data = Int16List(float32Data.length);
    for (int i = 0; i < float32Data.length; i++) {
        double sample = float32Data[i];
        if (sample > 1.0) sample = 1.0;
        if (sample < -1.0) sample = -1.0;
        pcm16Data[i] = (sample * 32767.0).toInt();
    }

    // Convert Int16List into Uint8List (bytes) to send over WebSocket
    final byteData = Uint8List.sublistView(pcm16Data);
    _onChunk!(byteData);
  }

  /// Gapless Web Audio API Playback for PCM16 chunks (e.g. at 24000 Hz)
  static double _nextPlayTime = 0.0;
  static web.AudioContext? _playbackContext;

  static void playAudioChunk(Uint8List pcmData, int sampleRate) {
    if (_playbackContext == null) {
      _playbackContext = web.AudioContext(web.AudioContextOptions(sampleRate: sampleRate));
      _nextPlayTime = _playbackContext!.currentTime;
    }

    final int16List = Int16List.sublistView(pcmData);
    final float32List = Float32List(int16List.length);
    for (int i = 0; i < int16List.length; i++) {
      float32List[i] = int16List[i] / 32768.0;
    }

    final audioBuffer = _playbackContext!.createBuffer(1, float32List.length, sampleRate);
    
    // In strict Dart-web JSInterop, JSFloat32Array cannot be iteratively written 
    // to using the []= operator. We must bulk copy the dart list to the channel.
    audioBuffer.copyToChannel(float32List.toJS, 0);

    final source = _playbackContext!.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(_playbackContext!.destination);

    if (_nextPlayTime < _playbackContext!.currentTime) {
      // If we fell behind, catch up to current time (plus a tiny safety buffer)
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

  /// Stop capturing audio and clean up the audio graph.
  static void stopRecording() {
    _processorNode?.disconnect();
    _sourceNode?.disconnect();
    
    if (_mediaStream != null) {
      final tracks = _mediaStream!.getTracks().toDart;
      for (final track in tracks.whereType<web.MediaStreamTrack>()) {
        track.stop();
      }
    }
    
    _audioContext?.close();

    _processorNode = null;
    _sourceNode = null;
    _audioContext = null;
    _mediaStream = null;
    _onChunk = null;
    
    debugPrint('WebAudioBridge: Recording stopped and graph dismantled.');
  }

  /// Synthesizes a subtle, high-tech ping sound indicating the AI is thinking.
  static void playPing() {
    try {
      final ctx = _playbackContext ?? web.AudioContext();
      final oscillator = ctx.createOscillator();
      final gain = ctx.createGain();

      oscillator.type = 'sine';
      oscillator.frequency.value = 880.0; // A5 note

      // Gentle ping envelope
      gain.gain.setValueAtTime(0.001, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.1, ctx.currentTime + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);

      oscillator.connect(gain);
      gain.connect(ctx.destination);
      oscillator.start(ctx.currentTime);
      oscillator.stop(ctx.currentTime + 0.3);
    } catch (_) {}
  }
}
