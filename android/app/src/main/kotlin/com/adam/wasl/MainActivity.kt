package com.adam.wasl

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    }

    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        NativeCrypto.register(messenger)
        VoiceRecorder.register(applicationContext, messenger)
        VideoCompressor.register(applicationContext, messenger)

        MethodChannel(messenger, "wasl/system").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "bluetoothSupported" -> result.success(bluetoothAdapter != null)
                    "bluetoothEnabled" -> result.success(bluetoothAdapter?.isEnabled == true)
                    "requestBluetoothOn" -> {
                        try {
                            startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                        }
                        result.success(null)
                    }
                    "locationEnabled" -> result.success(isLocationEnabled())
                    "openLocationSettings" -> {
                        startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                        result.success(null)
                    }
                    "wifiEnabled" -> {
                        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        result.success(wm?.isWifiEnabled == true)
                    }
                    "acquireMulticastLock" -> {
                        if (multicastLock?.isHeld != true) {
                            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                            multicastLock = wm?.createMulticastLock("wasl-discovery")?.apply {
                                setReferenceCounted(false)
                                acquire()
                            }
                        }
                        result.success(null)
                    }
                    "releaseMulticastLock" -> {
                        multicastLock?.let { if (it.isHeld) it.release() }
                        multicastLock = null
                        result.success(null)
                    }
                    "moveToBack" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "startChatService" -> {
                        ChatService.start(this)
                        result.success(null)
                    }
                    "updateChatService" -> {
                        ChatService.start(
                            this,
                            mic = call.argument<Boolean>("microphone") ?: false,
                            camera = call.argument<Boolean>("camera") ?: false,
                        )
                        result.success(null)
                    }
                    "stopChatService" -> {
                        ChatService.stop(this)
                        result.success(null)
                    }
                    "notify" -> {
                        Notifications.show(this, call.argument<String>("kind") ?: "message")
                        result.success(null)
                    }
                    "compressImage" -> {
                        val path = call.argument<String>("path") ?: ""
                        val maxSide = call.argument<Int>("maxSide") ?: 2048
                        val quality = call.argument<Int>("quality") ?: 82
                        Thread {
                            val out = try {
                                ImageCompressor.compress(path, java.io.File(cacheDir, "wasl_out"), maxSide, quality)
                            } catch (e: Throwable) {
                                null
                            }
                            runOnUiThread { result.success(out) }
                        }.start()
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        val name = call.argument<String>("name") ?: "file"
                        Thread {
                            val ok = try { ChatFiles.open(this, path, name) } catch (e: Exception) { false }
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path") ?: ""
                        val name = call.argument<String>("name") ?: "Wasl_file"
                        // النسخ ممكن ياخد وقت للملفات الكبيرة — برا الخيط الرئيسي
                        Thread {
                            val ok = try { ChatFiles.saveToDownloads(this, path, name) } catch (e: Exception) { false }
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "clearNotifications" -> {
                        Notifications.clear(this)
                        result.success(null)
                    }
                    "openWifiSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            Intent(Settings.Panel.ACTION_WIFI)
                        } else {
                            Intent(Settings.ACTION_WIFI_SETTINGS)
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("error", e.message, null)
            }
        }

        MethodChannel(messenger, "wasl/vault").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    // تشفير/فك مفتاح التخزين بمفتاح جوه Android Keystore (مبيطلعش برا الجهاز)
                    "wrap" -> result.success(KeyVault.wrap(call.argument<ByteArray>("data")!!))
                    "unwrap" -> result.success(KeyVault.unwrap(call.argument<ByteArray>("data")!!))
                    "biometricAvailable" -> result.success(BiometricGate.available(this))
                    "biometricAuth" -> BiometricGate.authenticate(
                        this,
                        call.argument<String>("title") ?: "Wasl",
                        call.argument<String>("subtitle") ?: "",
                        result,
                    )
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("vault", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        multicastLock?.let { if (it.isHeld) it.release() }
        if (isFinishing) ChatService.stop(this)
        super.onDestroy()
    }

    private fun isLocationEnabled(): Boolean {
        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }
}
