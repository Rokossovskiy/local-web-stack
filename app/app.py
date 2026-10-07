import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DEPS = {
    "postgres": (os.getenv("DB_HOST", "postgres"), int(os.getenv("DB_PORT", "5432"))),
    "redis": (os.getenv("REDIS_HOST", "redis"), int(os.getenv("REDIS_PORT", "6379"))),
}


def tcp_ok(host, port):
    # Проверка доступности зависимости по TCP, без драйверов
    try:
        with socket.create_connection((host, port), timeout=1):
            return True
    except OSError:
        return False


class Handler(BaseHTTPRequestHandler):
    # HTTP/1.1 нужен, чтобы работал keepalive от Nginx к upstream
    protocol_version = "HTTP/1.1"

    def _send(self, code, body):
        data = json.dumps(body, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/healthz":
            # Liveness: процесс жив
            return self._send(200, {"status": "ok"})
        if self.path == "/readyz":
            # Readiness: зависимости доступны
            deps = {name: tcp_ok(*addr) for name, addr in DEPS.items()}
            return self._send(200 if all(deps.values()) else 503, deps)
        self._send(200, {
            "path": self.path,
            "host": self.headers.get("Host"),
            "x_real_ip": self.headers.get("X-Real-IP"),
            "x_forwarded_for": self.headers.get("X-Forwarded-For"),
            "x_forwarded_proto": self.headers.get("X-Forwarded-Proto"),
            "x_forwarded_host": self.headers.get("X-Forwarded-Host"),
        })

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(length)
        self._send(200, {"received_bytes": length})


if __name__ == "__main__":
    port = int(os.getenv("APP_PORT", "8080"))
    print(f"listening on :{port}")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()

