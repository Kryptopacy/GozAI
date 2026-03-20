import http.server
import socketserver
import os

PORT = 3001
DIRECTORY = os.path.join(os.path.dirname(__file__), "..", "build", "web")

class ProperMimeHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def guess_type(self, path):
        if path.endswith('.js'):
            return 'application/javascript'
        if path.endswith('.wasm'):
            return 'application/wasm'
        return super().guess_type(path)

print(f"Serving {DIRECTORY} with proper MIME types at http://localhost:{PORT}")
with socketserver.TCPServer(("", PORT), ProperMimeHandler) as httpd:
    httpd.serve_forever()
