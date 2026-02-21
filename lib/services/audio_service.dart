import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_config.dart';

/// Service for bidirectional audio: mic capture → Gemini, Gemini → speaker.
///
/// Captures raw PCM audio at 16kHz mono for Gemini input,
/// and plays back 24kHz PCM audio responses from Gemini.
class AudioService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  StreamSubscription? _recordSubscription;

  // Stream controller for outbound PCM audio chunks
  final StreamController<Uint8List> _audioChunkController =
      StreamController<Uint8List>.broadcast();

  // Audio output buffer for seamless playback
  final List<Uint8List> _playbackBuffer = [];
  bool _isProcessingBuffer = false;

  // Public getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  Stream<Uint8List> get audioChunkStream => _audioChunkController.stream;

  /// Start recording audio from the microphone.
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint('AudioService: Microphone permission denied');
      return;
    }

    // Configure for PCM 16-bit mono at 16kHz (Gemini's expected format)
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: AppConfig.audioInputSampleRate,
      ),
    );

    _recordSubscription = stream.listen((data) {
      _audioChunkController.add(Uint8List.fromList(data));
    });

    _isRecording = true;
    notifyListeners();
    debugPrint('AudioService: Recording started (16kHz PCM mono)');
  }

  /// Stop recording audio.
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    await _recordSubscription?.cancel();
    _recordSubscription = null;
    await _recorder.stop();

    _isRecording = false;
    notifyListeners();
    debugPrint('AudioService: Recording stopped');
  }

  /// Queue PCM audio data from Gemini for playback.
  void queueAudioResponse(Uint8List pcmData) {
    _playbackBuffer.add(pcmData);
    _processPlaybackBuffer();
  }

  /// Stop any currently playing audio (for barge-in).
  Future<void> stopPlayback() async {
    _playbackBuffer.clear();
    await _player.stop();
    _isPlaying = false;
    notifyListeners();
  }

  /// Process the playback buffer sequentially.
  Future<void> _processPlaybackBuffer() async {
    if (_isProcessingBuffer || _playbackBuffer.isEmpty) return;
    _isProcessingBuffer = true;
    _isPlaying = true;
    notifyListeners();

    while (_playbackBuffer.isNotEmpty) {
      final chunk = _playbackBuffer.removeAt(0);
      try {
        // Create an audio source from raw PCM bytes
        // Using a custom StreamAudioSource for raw PCM playback
        final source = _PcmAudioSource(
          chunk,
          sampleRate: AppConfig.audioOutputSampleRate,
        );
        await _player.setAudioSource(source);
        await _player.play();

        // Wait for playback to complete
        await _player.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );
      } catch (e) {
        debugPrint('AudioService: Playback error: $e');
      }
    }

    _isPlaying = false;
    _isProcessingBuffer = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopRecording();
    stopPlayback();
    _recorder.dispose();
    _player.dispose();
    _audioChunkController.close();
    super.dispose();
  }
}

/// Custom audio source for raw PCM data playback.
class _PcmAudioSource extends StreamAudioSource {
  final Uint8List _pcmData;
  final int sampleRate;

  _PcmAudioSource(this._pcmData, {this.sampleRate = 24000});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final effectiveEnd = end ?? _pcmData.length;

    // Create a minimal WAV header for raw PCM data
    final wavData = _createWavHeader(
      _pcmData,
      sampleRate: sampleRate,
      numChannels: 1,
      bitsPerSample: 16,
    );

    return StreamAudioResponse(
      sourceLength: wavData.length,
      contentLength: effectiveEnd - effectiveStart,
      offset: effectiveStart,
      stream: Stream.value(
        wavData.sublist(effectiveStart, effectiveEnd),
      ),
      contentType: 'audio/wav',
    );
  }

  /// Create a WAV header for raw PCM data.
  Uint8List _createWavHeader(
    Uint8List pcmData, {
    required int sampleRate,
    required int numChannels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);

    // RIFF chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little);  // PCM format
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    // Combine header + data
    final result = Uint8List(44 + dataSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, pcmData);
    return result;
  }
}
