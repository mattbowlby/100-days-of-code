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
import android.os.UserManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

// One launchable app: what the home screen lists and starts.
data class AppEntry(
    // Stable across restarts, so it is what the dock refers to: the activity's
    // flattened component name, with the profile's serial number after a '#'
    // for apps outside the main profile (a work profile), where the same app
    // can be installed twice.
    val key: String,
    val label: String,
    val component: ComponentName,
    val user: UserHandle,
    val icon: ImageBitmap,
    // An adaptive icon, rendered from its own layers without the system's
    // mask: the tile clips it to the one app shape. Other icons already have a
    // shape of their own and are drawn whole.
    val adaptive: Boolean,
)

private class RenderedIcon(val updated: Long, val bitmap: ImageBitmap, val adaptive: Boolean)

// Every app with a launcher entry, in every profile, kept current as apps are
// installed, updated and removed. Icons are rendered off the main thread and
// kept, so only a package that changed is rendered again.
class AppRepository(private val context: Context) {
    private val launcherApps = context.getSystemService(LauncherApps::class.java)
    private val userManager = context.getSystemService(UserManager::class.java)
    private val mainUser = Process.myUserHandle()
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    var apps by mutableStateOf<List<AppEntry>>(emptyList())
        private set

    // Bumped per load; a load that is no longer the latest stops early and its
    // result is dropped.
    private val generation = AtomicInteger()

    // Rendered icons by entry key, with the package's update time they were
    // rendered at.
    private val icons = ConcurrentHashMap<String, RenderedIcon>()

    // An update of many apps at once (the Play Store's auto-update) arrives as
    // one callback per package; they are gathered into one load.
    private val reloadSoon = Runnable { reload() }
    private fun scheduleReload() {
        main.removeCallbacks(reloadSoon)
        main.postDelayed(reloadSoon, 300)
    }

    private val callback = object : LauncherApps.Callback() {
        override fun onPackageRemoved(packageName: String, user: UserHandle) = scheduleReload()
        override fun onPackageAdded(packageName: String, user: UserHandle) = scheduleReload()
        override fun onPackageChanged(packageName: String, user: UserHandle) = scheduleReload()
        override fun onPackagesAvailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = scheduleReload()
        override fun onPackagesUnavailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = scheduleReload()
    }

    // For the activity's whole life, not just while it is in front: package
    // changes are delivered while it is stopped too, so coming back home costs
    // nothing.
    fun start() {
        launcherApps.registerCallback(callback, main)
        reload()
    }

    fun close() {
        main.removeCallbacks(reloadSoon)
        launcherApps.unregisterCallback(callback)
        worker.shutdownNow()
    }

    fun reload() {
        val ticket = generation.incrementAndGet()
        val iconPx = (context.resources.displayMetrics.density * ICON_DP).toInt()
        val self = context.packageName
        worker.execute {
            val loaded = ArrayList<AppEntry>()
            for (profile in launcherApps.profiles) {
                for (info in launcherApps.getActivityList(null, profile)) {
                    if (generation.get() != ticket) return@execute
                    if (info.componentName.packageName == self) continue
                    // One broken icon must not cost the whole list.
                    runCatching { toEntry(info, iconPx) }.getOrNull()?.let { loaded.add(it) }
                }
            }
            loaded.sortBy { it.label.lowercase() }
            val live = loaded.mapTo(HashSet()) { it.key }
            icons.keys.retainAll(live)
            main.post { if (generation.get() == ticket) apps = loaded }
        }
    }

    fun launch(entry: AppEntry, sourceBounds: Rect? = null) {
        runCatching { launcherApps.startMainActivity(entry.component, entry.user, sourceBounds, null) }
    }

    fun openAppInfo(entry: AppEntry) {
        runCatching { launcherApps.startAppDetailsActivity(entry.component, entry.user, null, null) }
    }

    // A number that changes whenever the package is updated: its last update
    // time where this profile can see the package, else the path of its APK
    // (an update installs it at a new path).
    private fun versionStamp(info: LauncherActivityInfo): Long {
        val pkg = info.componentName.packageName
        return runCatching { context.packageManager.getPackageInfo(pkg, 0).lastUpdateTime }
            .getOrElse { info.applicationInfo.sourceDir.hashCode().toLong() }
    }

    private fun keyFor(info: LauncherActivityInfo): String {
        val component = info.componentName.flattenToString()
        return if (info.user == mainUser) component
        else component + "#" + userManager.getSerialNumberForUser(info.user)
    }

    private fun toEntry(info: LauncherActivityInfo, px: Int): AppEntry {
        val key = keyFor(info)
        val updated = versionStamp(info)
        val icon = icons[key]?.takeIf { it.updated == updated }
            ?: render(info, px, updated).also { icons[key] = it }
        return AppEntry(
            key = key,
            label = info.label.toString(),
            component = info.componentName,
            user = info.user,
            icon = icon.bitmap,
            adaptive = icon.adaptive,
        )
    }

    private fun render(info: LauncherActivityInfo, px: Int, updated: Long): RenderedIcon {
        // Badged: a work-profile app carries the briefcase, as it does elsewhere.
        val drawable = info.getBadgedIcon(context.resources.displayMetrics.densityDpi)
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val adaptive = drawable is AdaptiveIconDrawable && drawable.background != null
        if (drawable is AdaptiveIconDrawable && adaptive) {
            // The two layers without the system's mask, so the tile's rounded
            // square is the only shape. A layer is 108 units with the visible
            // 72 in the middle: drawn at 1.5x the bitmap, a quarter of it out
            // on each side.
            val bounds = Rect(-px / 4, -px / 4, px + px / 4, px + px / 4)
            for (layer in listOfNotNull(drawable.background, drawable.foreground)) {
                layer.bounds = bounds
                layer.draw(canvas)
            }
        } else {
            drawable.setBounds(0, 0, px, px)
            drawable.draw(canvas)
        }
        // Kept in graphics memory rather than on the app's heap.
        val stored = bitmap.copy(Bitmap.Config.HARDWARE, false) ?: bitmap
        if (stored !== bitmap) bitmap.recycle()
        return RenderedIcon(updated, stored.asImageBitmap(), adaptive)
    }

    companion object {
        // Rendered at the largest icon any layout draws (0.64 of a 64dp
        // tile); smaller ones scale it down.
        const val ICON_DP = 48
    }
}

