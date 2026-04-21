"""Simple SPA-aware HTTP server for Flutter web builds."""
import http.server
import os

WEB_DIR = os.path.join(os.path.dirname(__file__), 'build', 'web')
PORT = 8080

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        # Serve actual files if they exist, otherwise serve index.html (SPA fallback)
        path = self.translate_path(self.path)
        if not os.path.exists(path) or os.path.isdir(path) and not os.path.exists(os.path.join(path, 'index.html')):
            self.path = '/'
        return super().do_GET()

    def log_message(self, format, *args):
        # Quieter logging
        pass

if __name__ == '__main__':
    print(f'Serving Flutter web on http://localhost:{PORT}')
    print(f'Open http://localhost:{PORT} in your browser')
    with http.server.HTTPServer(('', PORT), SPAHandler) as server:
        server.serve_forever()
