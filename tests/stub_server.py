"""Tiny local stand-in for CLIProxyAPI used by tests/run.sh.

Usage: python3 tests/stub_server.py <mode> <port-file>
Modes: good (key required, 2 models), open (no key required), empty (no models).
Binds 127.0.0.1 on a free port and writes the port to <port-file>.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = sys.argv[1]
KEY = "test-key-not-secret"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/healthz":
            return self.send(200, {"status": "ok"})
        if self.path == "/v1/models":
            authorized = self.headers.get("Authorization") == f"Bearer {KEY}"
            if MODE != "open" and not authorized:
                return self.send(401, {"error": "unauthorized"})
            models = [] if MODE == "empty" else [{"id": "model-a"}, {"id": "model-b"}]
            return self.send(200, {"object": "list", "data": models})
        self.send(404, {"error": "not found"})


server = HTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[2], "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
