"""
Local Python Printer Bridge Server for C&J POS (Edge / Chrome / Web).
Listens on http://127.0.0.1:5858 and streams ESC/POS bytes directly to COM4 / COM3 without drivers.
"""

import base64
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

try:
    import serial
except ImportError:
    print("ERROR: pyserial is required. Run: python -m pip install pyserial")
    sys.exit(1)


def send_to_serial(payload: bytes, preferred_port: str = "COM4") -> bool:
    for port in [preferred_port, "COM3" if preferred_port == "COM4" else "COM4"]:
        try:
            with serial.Serial(port, baudrate=9600, timeout=3, write_timeout=3) as ser:
                ser.write(payload)
                ser.flush()
                print(f"[BRIDGE] Successfully printed {len(payload)} bytes to {port}!")
                return True
        except Exception as e:
            print(f"[BRIDGE] Port {port} error: {e}")
            continue
    return False


class PrinterBridgeHandler(BaseHTTPRequestHandler):
    def _set_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._set_cors_headers()
        self.end_headers()

    def do_GET(self):
        self.send_response(200)
        self._set_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        response = {
            "status": "ready",
            "printer": "JP58H-0A4B",
            "ports": ["COM4", "COM3"],
            "driverless": True
        }
        self.wfile.write(json.dumps(response).encode("utf-8"))

    def do_POST(self):
        if self.path == "/print":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            try:
                data = json.loads(body.decode("utf-8"))
                payload_b64 = data.get("payload", "")
                raw_bytes = base64.b64decode(payload_b64)
                
                success = send_to_serial(raw_bytes)
                if success:
                    self.send_response(200)
                    self._set_cors_headers()
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps({"success": True, "bytesPrinted": len(raw_bytes)}).encode("utf-8"))
                else:
                    self.send_response(500)
                    self._set_cors_headers()
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps({"success": False, "error": "Could not open COM4 or COM3."}).encode("utf-8"))
            except Exception as e:
                self.send_response(400)
                self._set_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "error": str(e)}).encode("utf-8"))
        else:
            self.send_response(404)
            self._set_cors_headers()
            self.end_headers()

    def log_message(self, format, *args):
        # Clean logging
        sys.stdout.write(f"[BRIDGE] {format % args}\n")
        sys.stdout.flush()


def run_server(port=5858):
    server = HTTPServer(("127.0.0.1", port), PrinterBridgeHandler)
    print(f"=======================================================")
    print(f"  C&J POS Thermal Printer Bridge (COM4 / Driverless)   ")
    print(f"  Listening on http://127.0.0.1:{port}/print          ")
    print(f"=======================================================")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping bridge server.")
        server.server_close()


if __name__ == "__main__":
    run_server()
