/**
 * GozAI Audio Worklet Processor
 * Converts float32 mic input to Int16 PCM chunks and posts them to the main thread.
 */
class PcmCaptureProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    // Buffer up audio until we have a 4096-sample chunk (matches old ScriptProcessor size)
    this._buffer = [];
    this._chunkSize = 4096;
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    if (!input || input.length === 0) return true;

    const channelData = input[0]; // mono
    for (let i = 0; i < channelData.length; i++) {
      this._buffer.push(channelData[i]);
    }

    // Once we have enough samples, convert and post
    while (this._buffer.length >= this._chunkSize) {
      const chunk = this._buffer.splice(0, this._chunkSize);
      const pcm16 = new Int16Array(chunk.length);
      for (let i = 0; i < chunk.length; i++) {
        let s = Math.max(-1, Math.min(1, chunk[i]));
        pcm16[i] = s * 32767;
      }
      // Transfer the underlying buffer to avoid copy overhead
      this.port.postMessage({ pcm16: pcm16.buffer }, [pcm16.buffer]);
    }

    return true; // keep processor alive
  }
}

registerProcessor('pcm-capture-processor', PcmCaptureProcessor);
