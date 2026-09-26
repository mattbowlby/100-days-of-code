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
    // Adaptive brightness is on: the level follows the light sensor. Moving
    // the slider switches it off, and the slider says so (its "Auto" label
    // goes), rather than changing the setting unseen.
    var autoBrightness by mutableStateOf(false)
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

        // Another app has the camera (or the flash is overheated): the torch
        // is off, whatever it was.
        override fun onTorchModeUnavailable(cameraId: String) {
            if (cameraId == torchCamera) torchOn = false
        }
    }

    // The brightness setting's own range: 1..255 on most phones, but the
    // platform's to say.
    private val brightnessMin: Int = platformInt("config_screenBrightnessSettingMinimum", 1)
    private val brightnessMax: Int = platformInt("config_screenBrightnessSettingMaximum", 255)
        .coerceAtLeast(brightnessMin + 1)

    private fun platformInt(name: String, fallback: Int): Int {
        val res = Resources.getSystem()
        val id = res.getIdentifier(name, "integer", "android")
        return if (id != 0) runCatching { res.getInteger(id) }.getOrDefault(fallback) else fallback
    }

    // Volume keys pressed while the panel is up move its slider too.
    private val volumeReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = refresh()
    }

    fun start() {
        runCatching { cameras?.registerTorchCallback(torchCallback, main) }
        runCatching {
            context.registerReceiver(
                volumeReceiver,
                android.content.IntentFilter("android.media.VOLUME_CHANGED_ACTION"),
                Context.RECEIVER_NOT_EXPORTED,
            )
        }
    }

    fun stop() {
        runCatching { cameras?.unregisterTorchCallback(torchCallback) }
        runCatching { context.unregisterReceiver(volumeReceiver) }
    }

    fun refresh() {
        val audio = audio ?: return
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        volume = audio.getStreamVolume(AudioManager.STREAM_MUSIC) / max.toFloat()
        canSetBrightness = runCatching { Settings.System.canWrite(context) }.getOrDefault(false)
        val resolver = context.contentResolver
        autoBrightness = runCatching {
            Settings.System.getInt(resolver, Settings.System.SCREEN_BRIGHTNESS_MODE) ==
                Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
        }.getOrDefault(false)
        brightness = runCatching {
            linearToGamma(Settings.System.getInt(resolver, Settings.System.SCREEN_BRIGHTNESS))
        }.getOrDefault(0.5f)
    }

    fun changeVolume(level: Float) {
        val audio = audio ?: return
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val index = Math.round(level.coerceIn(0f, 1f) * max)
        // Do Not Disturb can refuse a change; the slider then shows what stuck.
        runCatching { audio.setStreamVolume(AudioManager.STREAM_MUSIC, index, 0) }
        volume = audio.getStreamVolume(AudioManager.STREAM_MUSIC) / max.coerceAtLeast(1).toFloat()
    }

    // The slider is Android's own brightness curve, not the setting's raw
    // number: Samsung's slider (and AOSP's since Android 9) places a level by
    // perceived brightness, so the same level sits at the same point on both.
    // Never below 5% of the slider: a black screen is a phone that looks dead.
    // Adaptive brightness goes off -- the light sensor would otherwise undo
    // the change -- and the slider's "Auto" label goes with it.
    fun changeBrightness(level: Float) {
        if (!canSetBrightness) return
        val slider = level.coerceIn(BRIGHTNESS_FLOOR, 1f)
        val value = gammaToLinear(slider)
        val stored = runCatching {
            val resolver = context.contentResolver
            Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
            Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS, value)
        }.getOrDefault(false)
        if (stored) {
            autoBrightness = false
            brightness = slider
        }
    }

    // AOSP's BrightnessUtils: a hybrid log-gamma curve between the slider
    // (0..1) and the setting (min..max).
    private fun linearToGamma(value: Int): Float {
        val normalized = (value - brightnessMin).toFloat() / (brightnessMax - brightnessMin) * 12f
        val gamma = if (normalized <= 1f) kotlin.math.sqrt(normalized.coerceAtLeast(0f)) * R
        else A * kotlin.math.ln(normalized - B) + C
        return gamma.coerceIn(0f, 1f)
    }

    private fun gammaToLinear(slider: Float): Int {
        val linear = if (slider <= R) (slider / R) * (slider / R) else kotlin.math.exp((slider - C) / A) + B
        return Math.round(brightnessMin + (brightnessMax - brightnessMin) * (linear / 12f))
            .coerceIn(brightnessMin, brightnessMax)
    }

    companion object {
        private const val R = 0.5f
        private const val A = 0.17883277f
        private const val B = 0.28466892f
        private const val C = 0.55991073f
        const val BRIGHTNESS_FLOOR = 0.05f
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
    fun openWifi() {
        if (!open(Intent(Settings.Panel.ACTION_WIFI))) open(Intent(Settings.ACTION_WIFI_SETTINGS))
    }
    fun openBluetooth() = open(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
    fun openSettings() = open(Intent(Settings.ACTION_SETTINGS))

    private fun open(intent: Intent): Boolean =
        runCatching { context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }.isSuccess
}
