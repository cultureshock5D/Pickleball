"""
JP58H-0A4B Bluetooth Thermal Receipt Printer Direct Test Script
Sends raw ESC/POS commands directly over Bluetooth Virtual Serial Port (COM4 / COM3).
"""

import sys
import time
from datetime import datetime

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("Error: pyserial is required. Run: python -m pip install pyserial")
    sys.exit(1)


def generate_test_receipt() -> bytes:
    """Generate exact 32-column 58mm ESC/POS test receipt bytes."""
    ESC = b"\x1b"
    INIT = ESC + b"@"            # Initialize printer
    CENTER = ESC + b"a\x01"      # Center alignment
    LEFT = ESC + b"a\x00"        # Left alignment
    BOLD_ON = ESC + b"E\x01"     # Bold ON
    BOLD_OFF = ESC + b"E\x00"    # Bold OFF
    FEED = b"\n\n\n\n"           # Feed past tear-off cutter

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    buf = bytearray()
    buf.extend(INIT)
    buf.extend(CENTER)
    buf.extend(BOLD_ON)
    buf.extend(b"C&J SPORTS ARENA POS\n")
    buf.extend(b"** BLUETOOTH PRINT TEST **\n")
    buf.extend(BOLD_OFF)
    buf.extend(b"Printer: JP58H-0A4B (58mm)\n")
    buf.extend(f"Date: {now}\n".encode("ascii"))
    buf.extend(LEFT)
    buf.extend(b"--------------------------------\n")
    buf.extend(b"Item             Qty       Price\n")
    buf.extend(b"--------------------------------\n")
    buf.extend(b"Court 1 (Pickle)   1     P600.00\n")
    buf.extend(b"Bottled Water      2      P70.00\n")
    buf.extend(b"Overgrip           1     P150.00\n")
    buf.extend(b"--------------------------------\n")
    buf.extend(BOLD_ON)
    buf.extend(b"TOTAL AMOUNT:            P820.00\n")
    buf.extend(BOLD_OFF)
    buf.extend(b"Payment: CASH            P1000.0\n")
    buf.extend(b"Change:                  P180.00\n")
    buf.extend(b"--------------------------------\n")
    buf.extend(CENTER)
    buf.extend(BOLD_ON)
    buf.extend(b"*** TEST PRINT SUCCESSFUL ***\n")
    buf.extend(BOLD_OFF)
    buf.extend(b"Direct Bluetooth ESC/POS OK\n")
    buf.extend(FEED)

    return bytes(buf)


def test_print(target_port: str = None, baud_rate: int = 9600):
    ports = list(serial.tools.list_ports.comports())
    print("Available COM Ports:")
    for p in ports:
        print(f"  - {p.device}: {p.description}")

    # Prioritize COM4 then COM3 if not specified
    candidate_ports = []
    if target_port:
        candidate_ports = [target_port]
    else:
        for p in ports:
            if "Bluetooth" in p.description or p.device in ["COM4", "COM3"]:
                candidate_ports.append(p.device)
        # Ensure COM4 is tried first, then COM3
        if "COM4" in candidate_ports:
            candidate_ports.remove("COM4")
            candidate_ports.insert(0, "COM4")
        if "COM3" in candidate_ports and "COM3" not in candidate_ports[:1]:
            candidate_ports.append("COM3")

    if not candidate_ports:
        candidate_ports = ["COM4", "COM3"]

    receipt_bytes = generate_test_receipt()
    print(f"\nGenerated {len(receipt_bytes)} bytes of ESC/POS commands.")

    success = False
    for port in candidate_ports:
        print(f"\nAttempting to connect to {port} at {baud_rate} baud...")
        try:
            with serial.Serial(port, baudrate=baud_rate, timeout=4, write_timeout=4) as ser:
                print(f"Connected to {port}! Sending ESC/POS payload...")
                ser.write(receipt_bytes)
                ser.flush()
                time.sleep(1)
                print(f"\n>>> [SUCCESS] Data successfully sent to {port}!")
                print(">>> Check your JP58H-0A4B printer — it should be printing now!")
                success = True
                break
        except serial.SerialException as e:
            print(f"Failed to connect to {port}: {e}")
        except Exception as e:
            print(f"Unexpected error on {port}: {e}")

    if not success:
        print("\n[!] Could not print to candidate ports.")
        print("Please check:")
        print("1. Is the printer powered ON?")
        print("2. Is the printer paired in Windows Bluetooth settings?")
        print("3. Check Windows Bluetooth Settings -> More Bluetooth options -> COM Ports to verify outgoing port.")


if __name__ == "__main__":
    port_arg = sys.argv[1] if len(sys.argv) > 1 else None
    test_print(port_arg)
