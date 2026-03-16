class PcmProcessor extends AudioWorkletProcessor {
  process(inputs, outputs, parameters) {
    const input = inputs[0];
    if (input && input.length > 0) {
      const channelData = input[0]; // Float32Array
      if (channelData && channelData.length > 0) {
        // We must slice() the buffer because the browser reuses the underlying memory array
        // across process() calls, which would mutate data before the main thread reads it.
        this.port.postMessage(channelData.slice());
      }
    }
    // Return true to keep the processor alive indefinitely
    return true; 
  }
}

registerProcessor('pcm-processor', PcmProcessor);
