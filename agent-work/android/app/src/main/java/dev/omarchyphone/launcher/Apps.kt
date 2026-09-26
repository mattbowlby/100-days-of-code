package dev.omarchyphone.launcher

import android.content.ComponentName
import android.content.Context
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.graphics.drawable.AdaptiveIconDrawable
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import java.util.concurrent.Executors

// One launchable app: what the home screen lists and starts.
data class AppEntry(
    // The activity's flattened component name: stable across restarts, so it
    // is what the dock and saved order refer to.
    val key: String,
    val label: String,
    val component: ComponentName,
    val user: UserHandle,
    val icon: ImageBitmap,
    // Drawn edge to edge in the tile shape (adaptive icons, which carry a full
    // background layer), or on the frosted plate (older, shaped icons).
    val fullBleed: Boolean,
)

// Every app with a launcher entry for this user, kept current as apps are
// installed, updated and removed. Icons are rendered off the main thread.
class AppRepository(private val context: Context) {
    private val launcherApps = context.getSystemService(LauncherApps::class.java)
    private val user = Process.myUserHandle()
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    var apps by mutableStateOf<List<AppEntry>>(emptyList())
        private set

    // Bumped per load, so a slow load finishing after a newer one is dropped.
    private var generation = 0

    private val callback = object : LauncherApps.Callback() {
        override fun onPackageRemoved(packageName: String, user: UserHandle) = reload()
        override fun onPackageAdded(packageName: String, user: UserHandle) = reload()
        override fun onPackageChanged(packageName: String, user: UserHandle) = reload()
        override fun onPackagesAvailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = reload()
        override fun onPackagesUnavailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = reload()
    }

    fun start() {
        launcherApps.registerCallback(callback, main)
        reload()
    }

    fun stop() {
        launcherApps.unregisterCallback(callback)
    }

    fun reload() {
        val ticket = ++generation
        val iconPx = (context.resources.displayMetrics.density * ICON_DP).toInt()
        val self = context.packageName
        worker.execute {
            val loaded = launcherApps.getActivityList(null, user)
                .filter { it.componentName.packageName != self }
                .map { toEntry(it, iconPx) }
                .sortedBy { it.label.lowercase() }
            main.post { if (ticket == generation) apps = loaded }
        }
    }

    fun launch(entry: AppEntry, sourceBounds: Rect? = null) {
        runCatching { launcherApps.startMainActivity(entry.component, entry.user, sourceBounds, null) }
    }

    fun openAppInfo(entry: AppEntry) {
        runCatching { launcherApps.startAppDetailsActivity(entry.component, entry.user, null, null) }
    }

    private fun toEntry(info: LauncherActivityInfo, px: Int): AppEntry {
        val drawable = info.getIcon(context.resources.displayMetrics.densityDpi)
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val fullBleed = drawable is AdaptiveIconDrawable && drawable.background != null
        if (fullBleed) {
            // The two layers without the system's mask, so the tile's own
            // rounded square is the only shape. A layer is 108 units with the
            // visible 72 in the middle: drawn at 1.5x the tile, a quarter of
            // the tile out on each side.
            val bounds = Rect(-px / 4, -px / 4, px + px / 4, px + px / 4)
            for (layer in listOfNotNull(drawable.background, drawable.foreground)) {
                layer.bounds = bounds
                layer.draw(canvas)
            }
        } else {
            drawable.setBounds(0, 0, px, px)
            drawable.draw(canvas)
        }
        return AppEntry(
            key = info.componentName.flattenToString(),
            label = info.label.toString(),
            component = info.componentName,
            user = info.user,
            icon = bitmap.asImageBitmap(),
            fullBleed = fullBleed,
        )
    }

    companion object {
        // Rendered at the largest tile any layout asks for; smaller tiles scale
        // it down.
        const val ICON_DP = 72
    }
}
