package com.example.pickleball_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.pickleball_app/thermal_printer"
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val bluetoothReqCode = 1001
    private var pendingPermissionCallback: ((Boolean) -> Unit)? = null

    private fun checkAndRequestBluetoothPermission(onResult: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasConnect = checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            if (hasConnect) {
                onResult(true)
                return
            }
            pendingPermissionCallback = onResult
            requestPermissions(
                arrayOf(
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN
                ),
                bluetoothReqCode
            )
        } else {
            onResult(true)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == bluetoothReqCode) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            val cb = pendingPermissionCallback
            pendingPermissionCallback = null
            cb?.invoke(granted)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBluetoothPermissions" -> {
                    checkAndRequestBluetoothPermission { granted ->
                        result.success(granted)
                    }
                }
                "getPairedPrinters" -> {
                    checkAndRequestBluetoothPermission { granted ->
                        if (!granted) {
                            result.error(
                                "PERMISSION_DENIED",
                                "Nearby devices (Bluetooth) permission is required to search for XP-58H / JP58H printer. Please allow permission.",
                                null
                            )
                            return@checkAndRequestBluetoothPermission
                        }

                        try {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            if (adapter == null || !adapter.isEnabled) {
                                result.error("BLUETOOTH_DISABLED", "Bluetooth is turned OFF. Please enable Bluetooth on your phone.", null)
                                return@checkAndRequestBluetoothPermission
                            }

                            val pairedDevices = adapter.bondedDevices
                            val list = ArrayList<Map<String, String>>()
                            for (device: BluetoothDevice in pairedDevices) {
                                list.add(mapOf(
                                    "name" to (device.name ?: "Unknown Device"),
                                    "address" to device.address
                                ))
                            }
                            result.success(list)
                        } catch (e: Exception) {
                            result.error("SCAN_ERROR", e.localizedMessage, null)
                        }
                    }
                }
                "printRawBytes" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val targetAddress = call.argument<String>("address")

                    if (bytes == null || bytes.isEmpty()) {
                        result.error("EMPTY_BYTES", "No bytes provided to print.", null)
                        return@setMethodCallHandler
                    }

                    checkAndRequestBluetoothPermission { granted ->
                        if (!granted) {
                            result.error(
                                "PERMISSION_DENIED",
                                "Nearby devices (Bluetooth) permission is required to print to XP-58H / JP58H. Please allow permission.",
                                null
                            )
                            return@checkAndRequestBluetoothPermission
                        }

                        Thread {
                            try {
                                val adapter = BluetoothAdapter.getDefaultAdapter()
                                if (adapter == null || !adapter.isEnabled) {
                                    Handler(Looper.getMainLooper()).post {
                                        result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled on this device.", null)
                                    }
                                    return@Thread
                                }

                                // Find printer device from bonded/paired list
                                var targetDevice: BluetoothDevice? = null
                                val bonded = adapter.bondedDevices

                                if (!targetAddress.isNullOrEmpty()) {
                                    targetDevice = bonded.find { it.address.equals(targetAddress, ignoreCase = true) }
                                }

                                // Match by thermal printer signatures (XP-58H, JP58H, POS-58, etc.)
                                if (targetDevice == null) {
                                    targetDevice = bonded.find { device ->
                                        val name = device.name ?: ""
                                        name.contains("XP", ignoreCase = true) ||
                                        name.contains("58", ignoreCase = true) ||
                                        name.contains("JP", ignoreCase = true) ||
                                        name.contains("POS", ignoreCase = true) ||
                                        name.contains("0A4B", ignoreCase = true) ||
                                        name.contains("Printer", ignoreCase = true) ||
                                        name.contains("MPT", ignoreCase = true) ||
                                        name.contains("RPP", ignoreCase = true)
                                    }
                                }

                                // If not found by name, check device class for Imaging / Printer
                                if (targetDevice == null) {
                                    targetDevice = bonded.find { device ->
                                        device.bluetoothClass?.majorDeviceClass == BluetoothClass.Device.Major.IMAGING
                                    }
                                }

                                // Fallback to first paired device if available
                                if (targetDevice == null && bonded.isNotEmpty()) {
                                    targetDevice = bonded.first()
                                }

                                if (targetDevice == null) {
                                    Handler(Looper.getMainLooper()).post {
                                        result.error(
                                            "PRINTER_NOT_FOUND",
                                            "No paired thermal printer found. Please pair XP-58H in phone Bluetooth Settings (PIN: 0000 or 1234).",
                                            null
                                        )
                                    }
                                    return@Thread
                                }

                                // Connect via SPP Socket (RFCOMM)
                                var socket: BluetoothSocket? = null
                                try {
                                    adapter.cancelDiscovery()
                                    socket = targetDevice.createRfcommSocketToServiceRecord(sppUuid)
                                    socket.connect()

                                    val outputStream = socket.outputStream
                                    outputStream.write(bytes)
                                    outputStream.flush()
                                    Thread.sleep(400)

                                    val finalDeviceName = targetDevice.name ?: "XP-58H"
                                    Handler(Looper.getMainLooper()).post {
                                        result.success(mapOf(
                                            "success" to true,
                                            "deviceName" to finalDeviceName,
                                            "address" to targetDevice.address,
                                            "bytesPrinted" to bytes.size
                                        ))
                                    }
                                } catch (ioe: IOException) {
                                    Handler(Looper.getMainLooper()).post {
                                        result.error(
                                            "CONNECTION_FAILED",
                                            "Could not connect to ${targetDevice.name} (${targetDevice.address}): ${ioe.localizedMessage}. Please ensure XP-58H is turned ON.",
                                            null
                                        )
                                    }
                                } finally {
                                    try {
                                        socket?.close()
                                    } catch (_: Exception) {}
                                }
                            } catch (e: Exception) {
                                Handler(Looper.getMainLooper()).post {
                                    result.error("PRINT_ERROR", e.localizedMessage, null)
                                }
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
