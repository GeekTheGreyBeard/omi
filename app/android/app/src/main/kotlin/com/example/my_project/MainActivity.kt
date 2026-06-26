package com.friend.ios

import android.content.Intent
import android.content.Context
import android.provider.Settings
import android.os.Bundle
import android.os.Build
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.friend.ios/notifyOnKill"
    private val NATIVE_BLE_TRANSCRIPT_CHANNEL = "com.friend.ios/native_ble_transcript"
    private val DEVICE_IDENTITY_CHANNEL = "com.omi/device_identity"
    private var bleHostApiImpl: BleHostApiImpl? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register WiFi Network Plugin
        WifiNetworkPlugin.registerWith(flutterEngine, this)

        // Register Phone Calls Plugin
        PhoneCallsPlugin.registerWith(flutterEngine, this)

        // Register Native BLE Pigeon APIs
        OmiBleManager.initialize(application)
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.nativeBleForegroundReady", false)
            .apply()
        OmiBleManager.isFlutterAlive = true
        OmiBleManager.instance.flutterApi = BleFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
        val hostApi = BleHostApiImpl { this }
        hostApi.initCompanionManager(this)
        bleHostApiImpl = hostApi
        BleHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, hostApi)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_BLE_TRANSCRIPT_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "drain") {
                result.success(OmiBackgroundAudioStreamer.drainCachedTranscriptMessages())
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_IDENTITY_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getAuthIdentity") {
                result.success(readAuthIdentity())
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if(call.method == "setNotificationOnKillService"){
                 val title = call.argument<String>("title")
                val description = call.argument<String>("description")

                val serviceIntent = Intent(this, NotificationOnKillService::class.java)

                serviceIntent.putExtra("title", title)
                serviceIntent.putExtra("description", description)

                startService(serviceIntent)
                result.success(true)
            }else{
                result.notImplemented()
            }
        }
    }

    private fun readAuthIdentity(): Map<String, String> {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val phoneNumber = readPhoneNumber(telephonyManager)
        val imei = readImei(telephonyManager)
        if (!imei.isNullOrBlank()) {
            return mapOf(
                "phoneNumber" to phoneNumber.orEmpty(),
                "deviceIdentifier" to imei,
                "deviceIdentifierType" to "imei"
            )
        }

        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID).orEmpty()
        return mapOf(
            "phoneNumber" to phoneNumber.orEmpty(),
            "deviceIdentifier" to androidId,
            "deviceIdentifierType" to "android_id"
        )
    }

    private fun readPhoneNumber(telephonyManager: TelephonyManager): String? {
        return try {
            val hasReadPhoneNumbers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_NUMBERS) == PackageManager.PERMISSION_GRANTED
            } else {
                false
            }
            val hasReadPhoneState = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
            if (hasReadPhoneNumbers || hasReadPhoneState) telephonyManager.line1Number else null
        } catch (_: Exception) {
            null
        }
    }

    private fun readImei(telephonyManager: TelephonyManager): String? {
        return try {
            val hasReadPhoneState = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
            if (!hasReadPhoneState) return null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) telephonyManager.imei else telephonyManager.deviceId
        } catch (_: Exception) {
            null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        // Handle CompanionDeviceManager chooser result
        val address = bleHostApiImpl?.onActivityResult(requestCode, resultCode, data)
        if (address != null) {
            // Device selected — start foreground service (Dart will call manageDevice)
            OmiBleForegroundService.startService(this, address, caller = "MainActivity.onActivityResult")
        }
    }

    override fun onResume() {
        super.onResume()
        OmiBleManager.isAppForeground = true
    }

    override fun onPause() {
        OmiBleManager.isAppForeground = false
        super.onPause()
    }

    override fun onDestroy() {
        if (isFinishing) {
            OmiBleManager.isFlutterAlive = false
            // With Background Mode on, the foreground service keeps the pendant connected and
            // transcribing after a task close. With it off (default), tear it down so the device
            // disconnects when the app is closed.
            if (!OmiBleForegroundService.isBackgroundModeEnabled(this)) {
                OmiBleForegroundService.stopService(this)
            }
        }
        super.onDestroy()
    }
}
