# GozAI: Native & Wearable Architecture Blueprint

*This document outlines the post-PWA roadmap for GozAI, detailing how the Universal UI Navigator and core services translate to native operating systems and dedicated wearable hardware.*

## 1. Android Native Implementation
Android provides the required deep-system hooks to achieve a true "Zero-UI" completely hands-free experience.

### Screen Capture API (`MediaProjection`)
Instead of the web `getDisplayMedia` or Flutter `RepaintBoundary`, the app utilizes the `MediaProjection` API. This allows GozAI to continuously stream the entire phone screen back to the Gemini backend, regardless of which app is currently in the foreground.

### Execution: `AccessibilityService`
This is where the magic happens for Android. The GozAI app registers as a system-level Accessibility Service. 
When the backend Gemini agent outputs `clickUiElement(x, y)`:
1. The Flutter frontend receives the coordinate via WebSocket.
2. Flutter passes the coordinate to a Native Kotlin MethodChannel.
3. The Kotlin `AccessibilityService` uses the `dispatchGesture` API to inject a synthetic touchscreen tap at `(x, y)` universally across the OS.

## 2. iOS Native Implementation
iOS sandboxing is notoriously strict. A true "Ghost Touch" system-wide accessibility service is not possible without jailbreaking or Mobile Device Management (MDM) profiles.

### Screen Capture (`ReplayKit`)
GozAI implements a Broadcast Upload Extension via `ReplayKit`. The user explicitly starts a screen broadcast, which the extension captures frame-by-frame and streams to Gemini.

### Execution: "Guided Autonomy" & VoiceOver Interop
Since iOS blocks synthetic background taps, GozAI relies on:
1. **Haptic Sonar:** Gemini provides the target coordinates. As the user drags their finger, GozAI provides increasing frequency haptic pulses as the finger nears the target coordinate.
2. **Shortcuts Integration:** Deep integration with Apple Shortcuts to execute system tasks (e.g., "Siri, tell GozAI to text Mom") via pre-defined intents, bypassing UI entirely where possible.

## 3. Wearables & Smart Glasses (The Ultimate Vision)
A phone camera is clumsy; the true form-factor for GozAI is a head-mounted display (HMD) or smart glasses (e.g., Ray-Ban Meta, Vuzix).

### Point-of-View Capture
The glasses' camera becomes the perpetual "Scene Mode" eye. Frames are streamed via Bluetooth/Wi-Fi to the companion phone, and then to Gemini.

### Execution: Bluetooth HID Profile
The glasses act as a Virtual Bluetooth Mouse to the user's phone or computer.
1. User: "Goz, click 'Allow' on that popup."
2. Gemini (seeing the phone screen through the glasses camera) calculates the bounding box of the 'Allow' button relative to the phone bezel.
3. Gemini outputs `Mouse(x, y, Click)`.
4. The glasses transmit a Bluetooth HID Mouse Event to the phone, injecting the tap.

This entirely solves the OS sandboxing issue, as the phone interprets the command as physical hardware input.
