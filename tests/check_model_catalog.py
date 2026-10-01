#!/usr/bin/env python3
"""Exercise the real Swift catalog loader against a local HTTP server."""
import collections
import http.server
import json
from pathlib import Path
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
COUNTS = collections.Counter()
VALID = {"models": [{"id": "test/new", "label": "New"}],
         "replacedModelIDs": {"test/old": "test/new"}}


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        COUNTS[self.path] += 1
        if self.path == "/disconnect":
            self.connection.close()
            return
        body = json.dumps(VALID).encode()
        if self.path == "/invalid":
            body = b"not JSON"
        elif self.path == "/empty":
            body = b'{"models": [], "replacedModelIDs": {}}'
        elif self.path == "/duplicate":
            body = json.dumps({"models": VALID["models"] * 2, "replacedModelIDs": {}}).encode()
        elif self.path == "/bad-replacement":
            body = json.dumps({"models": VALID["models"], "replacedModelIDs": {"old": "missing"}}).encode()
        elif self.path == "/oversized":
            body = b" " * (65 * 1024)
        self.send_response(503 if self.path == "/http-error" else 200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass


with tempfile.TemporaryDirectory(prefix="lightweight-catalog-") as temporary:
    executable = Path(temporary) / "checks"
    subprocess.run(["swiftc", "-parse-as-library",
                    str(ROOT / "LightweightChat/Sources/Models.swift"),
                    str(ROOT / "LightweightChat/Sources/ModelCatalogStore.swift"),
                    str(ROOT / "tests/ModelCatalogChecks.swift"), "-o", str(executable)], check=True)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        subprocess.run([str(executable), f"http://127.0.0.1:{server.server_port}", temporary,
                        str(ROOT / "LightweightChat/Resources/models.json")], check=True)
        assert COUNTS["/valid"] == 2, COUNTS
        for path in ["invalid", "empty", "duplicate", "bad-replacement", "http-error", "oversized"]:
            assert COUNTS[f"/{path}"] == 1, COUNTS
        print("HTTP request counts confirm daily checks and failure throttling")
    finally:
        server.shutdown()
        server.server_close()
