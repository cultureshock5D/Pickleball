@echo off
echo =======================================================
echo   Starting C^&J POS Driverless Thermal Printer Bridge
echo   Connecting to JP58H-0A4B (COM4 / COM3)...
echo =======================================================
python "%~dp0scripts\printer_bridge_server.py"
pause
