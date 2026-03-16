class PcmProcessor extends AudioWorkletProcessor {
  process(inputs, outputs, parameters) {
    const input = inputs[0];
    if (input && input.length > 0) {
      const channelData = input[0]; // Float32Array
      if (channelData && channelData.length > 0) {
        // Convert Float32 to Int16
        const pcm16 = new Int16Array(channelData.length);
        for (let i = 0; i < channelData.length; i++) {
          let s = Math.max(-1, Math.min(1, channelData[i]));
          pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
        }
        // Send as { pcm16: ArrayBuffer } to match _WorkletMessage interface in Dart
        this.port.postMessage({ pcm16: pcm16.buffer }, [pcm16.buffer]);
      }
    }
    // Return true to keep the processor alive indefinitely
    return true; 
  }
}

registerProcessor('pcm-processor', PcmProcessor);
