"""
Direct ESC/POS stream utility for Windows POS.
Streams raw bytes to any connected thermal receipt printer (all COM ports).
"""

import sys
import os

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial is required. Run: python -m pip install pyserial")
    sys.exit(1)


def send_bytes_to_printer(payload: bytes, preferred_port: str = "COM4") -> bool:
    try:
        detected_ports = [p.device for p in serial.tools.list_ports.comports()]
    except Exception:
        detected_ports = []

    ports_to_try = []
    for p in [preferred_port, "COM3", "COM1", "COM2", "COM5"]:
        if p not in ports_to_try:
            ports_to_try.append(p)
    for p in detected_ports:
        if p not in ports_to_try:
            ports_to_try.append(p)

    for port in ports_to_try:
        try:
            with serial.Serial(port, baudrate=9600, timeout=3, write_timeout=3) as ser:
                ser.write(payload)
                ser.flush()
                print(f"SUCCESS: Sent {len(payload)} bytes to {port}")
                return True
        except Exception:
            continue

    print(f"ERROR: Could not open any serial port (tried {', '.join(ports_to_try[:6])}).")
    return False


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python print_escpos_windows.py <path_to_binary_file>")
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"ERROR: File not found: {file_path}")
        sys.exit(1)

    with open(file_path, "rb") as f:
        data = f.read()

    if send_bytes_to_printer(data):
        sys.exit(0)
    else:
        sys.exit(1)

