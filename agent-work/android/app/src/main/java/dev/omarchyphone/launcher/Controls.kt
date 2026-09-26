package dev.omarchyphone.launcher

import android.content.Context
import android.content.Intent
import android.content.res.Resources
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

// What the control panel reads and sets: media volume, screen brightness and
// the flashlight, each through the ordinary Android API for it. Brightness is
// a system setting, so it needs the "modify system settings" permission, which
// only the user can grant, on a settings page; until then its slider asks for
// it instead of moving.
class Controls(private val context: Context) {
    // Nullable only for the screenshot renderer, which has neither service.
    private val audio: AudioManager? = runCatching { context.getSystemService(AudioManager::class.java) }.getOrNull()
    private val cameras: CameraManager? = runCatching { context.getSystemService(CameraManager::class.java) }.getOrNull()
    private val main = Handler(Looper.getMainLooper())

    // 0..1; read again each time the panel opens, since the volume keys and
    // Samsung's own panel change both behind our back.
    var volume by mutableFloatStateOf(0f)
        private set
    var brightness by mutableFloatStateOf(0f)
        private set
    var canSetBrightness by mutableStateOf(false)
        private set

    // The first camera with a flash, if the phone has one.
    private val torchCamera: String? = runCatching {
        cameras?.cameraIdList?.firstOrNull {
            cameras.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
    }.getOrNull()
    val hasTorch get() = torchCamera != null
    var torchOn by mutableStateOf(false)
        private set

    private val torchCallback = object : CameraManager.TorchCallback() {
        override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
            if (cameraId == torchCamera) torchOn = enabled
        }
    }

    // The brightness setting's own range: 255 on most phones, but the maximum
    // is the platform's to say.
    private val brightnessMax: Int = run {
        val res = Resources.getSystem()
        val id = res.getIdentifier("config_screenBrightnessSettingMaximum", "integer", "android")
        if (id != 0) runCatching { res.getInteger(id) }.getOrDefault(255).coerceAtLeast(1) else 255
    }

    fun start() {
        runCatching { cameras?.registerTorchCallback(torchCallback, main) }
    }

    fun stop() {
        runCatching { cameras?.unregisterTorchCallback(torchCallback) }
    }

    fun refresh() {
        val audio = audio ?: return
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        volume = audio.getStreamVolume(AudioManager.STREAM_MUSIC) / max.toFloat()
        canSetBrightness = runCatching { Settings.System.canWrite(context) }.getOrDefault(false)
        brightness = runCatching {
            Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS) / brightnessMax.toFloat()
        }.getOrDefault(0.5f).coerceIn(0f, 1f)
    }

    fun changeVolume(level: Float) {
        val audio = audio ?: return
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val index = Math.round(level.coerceIn(0f, 1f) * max)
        // Do Not Disturb can refuse a change; the slider then shows what stuck.
        runCatching { audio.setStreamVolume(AudioManager.STREAM_MUSIC, index, 0) }
        volume = audio.getStreamVolume(AudioManager.STREAM_MUSIC) / max.coerceAtLeast(1).toFloat()
    }

    // Never below 5%: a black screen is a phone that looks dead. Automatic
    // brightness is switched off, as moving Samsung's own slider does, or the
    // light sensor would undo the change a moment later.
    fun changeBrightness(level: Float) {
        if (!canSetBrightness) return
        val value = Math.round(level.coerceIn(0.05f, 1f) * brightnessMax)
        runCatching {
            val resolver = context.contentResolver
            Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
            Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS, value)
        }
        brightness = value / brightnessMax.toFloat()
    }

    // The settings page where the user lets this app change brightness.
    fun askForBrightness() {
        val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:" + context.packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(intent) }
    }

    fun toggleTorch() {
        val camera = torchCamera ?: return
        runCatching { cameras?.setTorchMode(camera, !torchOn) }
    }

    // The Wi-Fi and Bluetooth tiles open Android's own quick panels for them:
    // an app may no longer switch either on or off itself.
    fun openWifi() = open(Intent(Settings.Panel.ACTION_WIFI))
    fun openBluetooth() = open(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
    fun openSettings() = open(Intent(Settings.ACTION_SETTINGS))

    private fun open(intent: Intent) {
        runCatching { context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }
}
