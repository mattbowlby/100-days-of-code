package dev.omarchyphone.launcher

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.provider.Telephony
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

// What the user has chosen: the Omarchy theme and the dock. Kept in shared
// preferences, and as Compose state so the screen follows a change at once.
class LauncherSettings(private val context: Context) {
    // Absent only where there is no Android behind the context (the
    // screenshot renderer); choices then last as long as the screen does.
    private val prefs: android.content.SharedPreferences? = context.getSharedPreferences("launcher", Context.MODE_PRIVATE)

    var themeId by mutableStateOf(prefs?.getString(KEY_THEME, null) ?: "tokyo-night")
        private set

    // Component keys (AppEntry.key), left to right. Null until the user first
    // changes the dock: until then it is worked out from the phone's own
    // default apps, so it follows a default the user changes in Android.
    var dockKeys by mutableStateOf(prefs?.getString(KEY_DOCK, null)?.let { decode(it) })
        private set

    fun setTheme(id: String) {
        themeId = id
        prefs?.edit()?.putString(KEY_THEME, id)?.apply()
    }

    fun setDock(keys: List<String>) {
        val kept = keys.distinct().take(DOCK_SIZE)
        dockKeys = kept
        prefs?.edit()?.putString(KEY_DOCK, encode(kept))?.apply()
    }

    // The dock iOS starts with -- phone, messages, browser, camera -- as this
    // phone's default app for each, where it has one.
    fun defaultDock(): List<String> {
        val pm = context.packageManager
        val intents = listOf(
            Intent(Intent.ACTION_DIAL),
            Telephony.Sms.getDefaultSmsPackage(context)?.let { pkg ->
                pm.getLaunchIntentForPackage(pkg)
            } ?: Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_MESSAGING),
            Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com")),
            Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA),
        )
        return intents.mapNotNull { launcherKeyFor(it) }.distinct()
    }

    // The launcher entry of the app that would handle an intent: resolved to
    // its package, then to that package's own launcher activity, since the
    // activity that handles, say, a web link is not the one the icon opens.
    private fun launcherKeyFor(intent: Intent): String? {
        val pm = context.packageManager
        // A category-only selector (messaging, on a phone with no SMS app of
        // its own) is on launcher entries that do not carry DEFAULT.
        val flags = if (intent.selector != null) 0 else PackageManager.MATCH_DEFAULT_ONLY
        val pkg = intent.component?.packageName
            ?: pm.resolveActivity(intent, flags)?.activityInfo?.packageName
            ?: return null
        // "android" is the chooser: no default is set for this kind of app.
        if (pkg == "android") return null
        val launch = pm.getLaunchIntentForPackage(pkg)?.component ?: return null
        return ComponentName(launch.packageName, launch.className).flattenToString()
    }

    private fun encode(keys: List<String>) = keys.joinToString("\n")
    private fun decode(value: String) = value.split("\n").filter { it.isNotBlank() }

    companion object {
        const val DOCK_SIZE = 4
        private const val KEY_THEME = "theme"
        private const val KEY_DOCK = "dock"
    }
}
