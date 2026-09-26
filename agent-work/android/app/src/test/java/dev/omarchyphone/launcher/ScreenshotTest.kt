package dev.omarchyphone.launcher

import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.os.Process
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import app.cash.paparazzi.DeviceConfig
import app.cash.paparazzi.Paparazzi
import org.junit.Rule
import org.junit.Test

// Renders the home screen on a computer (Paparazzi, no phone), over one of
// Omarchy's wallpapers, with stand-in apps: the icons from Omarchy's web apps
// (shaped icons, drawn on the frosted plate) and a set of made-up adaptive
// icons (drawn edge to edge). `gradle recordPaparazziDebug` writes the PNGs
// to app/src/test/snapshots/images/.
class ScreenshotTest {
    @get:Rule
    val paparazzi = Paparazzi(deviceConfig = GALAXY_S23, theme = "android:Theme.Material.NoActionBar")

    private fun resource(name: String): Bitmap =
        javaClass.classLoader!!.getResourceAsStream(name).use { BitmapFactory.decodeStream(it) }

    private fun shapedApps(): List<AppEntry> =
        listOf("Google_Maps", "Google_Photos", "WhatsApp", "YouTube", "Zoom", "Google_Messages",
            "Basecamp", "ChatGPT", "HEY", "X", "Docker", "Google_Contacts").map { name ->
            entry(name.replace('_', ' '), resource("icons/$name.png"), fullBleed = false)
        }

    // Edge-to-edge icons as most Samsung and Google apps ship them: a coloured
    // background layer with a white glyph.
    private fun adaptiveApps(): List<AppEntry> =
        listOf(
            "Phone" to (0xFF34C759.toInt() to "☎"),
            "Messages" to (0xFF30B0FF.toInt() to "✉"),
            "Internet" to (0xFF5E5CE6.toInt() to "◎"),
            "Camera" to (0xFF8E8E93.toInt() to "◉"),
            "Calendar" to (0xFFFF3B30.toInt() to "26"),
            "Clock" to (0xFF1C1C1E.toInt() to "◴"),
            "Gallery" to (0xFFFF2D55.toInt() to "✿"),
            "Settings" to (0xFF636366.toInt() to "⚙"),
        ).map { (label, spec) -> entry(label, glyphIcon(spec.first, spec.second), fullBleed = true) }

    private fun glyphIcon(color: Int, glyph: String): Bitmap {
        val px = 216
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val bg = Paint().apply {
            shader = LinearGradient(0f, 0f, 0f, px.toFloat(), color, darker(color), Shader.TileMode.CLAMP)
        }
        canvas.drawRect(0f, 0f, px.toFloat(), px.toFloat(), bg)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = 0xFFFFFFFF.toInt()
            textSize = px * 0.42f
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(glyph, px / 2f, px / 2f - (text.ascent() + text.descent()) / 2, text)
        return bitmap
    }

    private fun darker(color: Int): Int {
        val r = (color shr 16 and 0xFF) * 3 / 4
        val g = (color shr 8 and 0xFF) * 3 / 4
        val b = (color and 0xFF) * 3 / 4
        return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
    }

    private fun entry(label: String, icon: Bitmap, fullBleed: Boolean) = AppEntry(
        key = "test/$label",
        label = label,
        component = ComponentName("test", label),
        user = Process.myUserHandle(),
        icon = icon.asImageBitmap(),
        adaptive = fullBleed,
    )

    private fun apps() = (adaptiveApps() + shapedApps()).sortedBy { it.label.lowercase() }

    @Composable
    private fun OnWallpaper(content: @Composable () -> Unit) {
        Box(Modifier.fillMaxSize()) {
            Image(resource("wallpaper.png").asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            content()
        }
    }

    private fun home(themeId: String) {
        val settings = LauncherSettings(paparazzi.context)
        settings.setTheme(themeId)
        settings.setDock(listOf("test/Phone", "test/Messages", "test/Internet", "test/Camera"))
        val actions = HomeActions(launch = {}, appInfo = {}, uninstall = {})
        paparazzi.snapshot {
            OnWallpaper {
                HomeScreen(apps(), settings, actions, homePresses = 0, onSearchOpenChanged = {})
            }
        }
    }

    @Test fun homeTokyoNight() = home("tokyo-night")

    @Test
    fun homeFoldUnfolded() {
        paparazzi.unsafeUpdateConfig(deviceConfig = GALAXY_Z_FOLD_INNER)
        home("tokyo-night")
    }

    @Test fun homeCatppuccinLatte() = home("catppuccin-latte")

    @Test
    fun search() {
        val theme = themeById("tokyo-night")
        paparazzi.snapshot {
            OnWallpaper {
                SearchSheet(apps(), theme, tile = 60.androidx(), onLaunch = {}, onClose = {})
            }
        }
    }

    @Test
    fun controlPanel() {
        val controls = Controls(paparazzi.context)
        paparazzi.snapshot {
            OnWallpaper { ControlPanel(controls, themeById("tokyo-night"), tile = 64.androidx(), onClose = {}) }
        }
    }

    @Test
    fun themePicker() {
        paparazzi.snapshot {
            OnWallpaper { ThemePicker(themeById("tokyo-night"), onPick = {}, onClose = {}) }
        }
    }
}

// A Galaxy S23-sized phone (1080x2340, 360dp wide at 480 dpi) and a Z Fold's unfolded
// inner screen (2176x1812): Paparazzi ships Pixel configurations only.
private val GALAXY_S23 = DeviceConfig.PIXEL_6.copy(
    screenWidth = 1080, screenHeight = 2340, xdpi = 425, ydpi = 425,
    density = com.android.resources.Density.XXHIGH,
)
private val GALAXY_Z_FOLD_INNER = DeviceConfig.PIXEL_6.copy(
    screenWidth = 2176, screenHeight = 1812, xdpi = 374, ydpi = 374,
    density = com.android.resources.Density.XXHIGH,
)

private fun Int.androidx() = androidx.compose.ui.unit.Dp(this.toFloat())
