import os
import re

def resolve_gitignore():
    path = '.gitignore'
    with open(path, 'r') as f:
        content = f.read()
    
    resolved = re.sub(
        r'<<<<<<< HEAD\n/build/\*\n=======\n/build/\n>>>>>>> recovered-features',
        '/build/',
        content
    )
    with open(path, 'w') as f:
        f.write(resolved)

def resolve_gradle():
    path = 'android/gradle.properties'
    with open(path, 'r') as f:
        content = f.read()
    
    resolved = re.sub(
        r'<<<<<<< HEAD\norg\.gradle\.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=256m -XX:\+HeapDumpOnOutOfMemoryError\n=======\norg\.gradle\.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=512m -XX:\+HeapDumpOnOutOfMemoryError\n>>>>>>> recovered-features',
        'org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError',
        content
    )
    with open(path, 'w') as f:
        f.write(resolved)

def resolve_vercel():
    path = 'vercel.json'
    with open(path, 'r') as f:
        content = f.read()
    
    resolved = re.sub(
        r'<<<<<<< HEAD\n  "outputDirectory": "build/web",\n  "rewrites": \[\n    \{\n      "source": "/\(\.\*\)",\n      "destination": "/index\.html"\n=======\n  "rewrites": \[\n    \{\n      "source": "/\(\.\*\)",\n      "destination": "/build/web/\$1"\n    \},\n    \{\n      "source": "/",\n      "destination": "/build/web/index\.html"\n>>>>>>> recovered-features\n    \}',
        '  "outputDirectory": "build/web",\n  "rewrites": [\n    {\n      "source": "/(.*)",\n      "destination": "/index.html"\n    }',
        content
    )
    with open(path, 'w') as f:
        f.write(resolved)

def resolve_stub():
    path = 'lib/services/audio_service_stub.dart'
    content = """// This is the NATIVE stub for the WebAudioBridge.
// Used on iOS/Android — web audio is not needed on native platforms.
import 'dart:typed_data';

/// Stub implementation for native platforms.
/// On native, AudioService uses the `record` package directly.
class WebAudioBridge {
  static Future<bool> startRecording({
    required void Function(Uint8List chunk) onChunk,
  }) async {
    return false; // Not used on native
  }

  static void stopRecording() {
    // Not used on native
  }

  static void playAudioChunk(Uint8List chunk, int sampleRate) {
    // Not used on native
  }

  static void stopPlayback() {
    // Not used on native
  }

  static void playPing() {
    // Not used on native
  }
}
"""
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def resolve_web():
    path = 'lib/services/audio_service_web.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # We take the HEAD content but append the playPing method right before the last closing brace
    # Extract the HEAD block
    match = re.search(r'<<<<<<< HEAD\n(.*?)\n=======\n.*?\n>>>>>>> recovered-features\n', content, flags=re.DOTALL)
    if match:
        head_content = match.group(1)
        # Add playPing to it
        play_ping = '''
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
'''
        # insert before last brace
        head_content = head_content.rstrip()
        final_content = head_content[:-1] + play_ping + "}\n"
        with open(path, 'w', encoding='utf-8') as f:
            f.write(final_content)

resolve_gitignore()
resolve_gradle()
resolve_vercel()
resolve_stub()
resolve_web()
print("Resolved easy conflicts.")
