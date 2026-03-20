#!/usr/bin/env bash
# Compiles the Flutter web application using CanvasKit (WebGL/WASM)
# This overrides the HTML renderer, completely bypassing DOM Node Inserted events
# and resulting in a much faster, fully conformant web app when rendering complex
# camera textures like Goz View.

echo "Building GozAI for Web with CanvasKit..."
flutter build web --web-renderer canvaskit
echo "Build complete."
