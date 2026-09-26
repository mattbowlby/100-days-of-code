package dev.omarchyphone.launcher

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue

// The home screen. Android starts it for the Home button once it is chosen as
// the phone's home app (on a Samsung: Settings > Apps > Choose default apps >
// Home app).
class HomeActivity : ComponentActivity() {
    private lateinit var repository: AppRepository
    private lateinit var settings: LauncherSettings
    private lateinit var controls: Controls

    // Counts Home presses while the home screen is already showing, which
    // HomeScreen answers by going back to the first page.
    private var homePresses by mutableIntStateOf(0)
    private var searchOpen = false

    // A home screen has nowhere to go back to, so Back is taken and does
    // nothing. Open sheets close on Back through HomeScreen's own handler,
    // which comes first.
    private val back = object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {}
    }

    private val blurListener = java.util.function.Consumer<Boolean> { applyBlur() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        repository = AppRepository(this)
        settings = LauncherSettings(this)
        controls = Controls(this)
        onBackPressedDispatcher.addCallback(this, back)
        density = resources.configuration.densityDpi
        repository.start()

        setContent {
            HomeScreen(
                apps = repository.apps,
                settings = settings,
                homePresses = homePresses,
                actions = HomeActions(
                    launch = { repository.launch(it) },
                    appInfo = { repository.openAppInfo(it) },
                    uninstall = { uninstall(it) },
                ),
                onSearchOpenChanged = { open -> setSearchOpen(open) },
                controls = controls,
            )
        }
    }

    override fun onStart() {
        super.onStart()
        windowManager.addCrossWindowBlurEnabledListener(mainExecutor, blurListener)
        controls.start()
    }

    override fun onStop() {
        windowManager.removeCrossWindowBlurEnabledListener(blurListener)
        controls.stop()
        super.onStop()
    }

    // Density changes without recreating the activity (display size, or a
    // Fold moving between screens): icons are rendered again at the new size.
    private var density = 0

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        if (newConfig.densityDpi != density) {
            density = newConfig.densityDpi
            repository.reload()
        }
    }

    override fun onDestroy() {
        repository.close()
        super.onDestroy()
    }

    // Home pressed with the home screen already in front.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Already home when the press did not have to bring this to the front
        // (as Launcher3 decides it), or when it has the focus. The flag, not
        // the focus alone: an open long-press menu holds the focus in its own
        // window, and a Home press should close it.
        val broughtToFront = (intent.flags and Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT) != 0
        if (Intent.ACTION_MAIN == intent.action && (hasWindowFocus() || !broughtToFront)) homePresses++
    }

    // The wallpaper frosts over behind search, as the home screen does on iOS,
    // where the phone supports blurring behind a window (Samsung's flagships
    // do; the setting can also be off to save battery). Without it the sheet's
    // own tint still separates it.
    // Asked again whenever the phone turns blur on or off (battery saver
    // does), so a blur switched off mid-search never comes back stuck on.
    private fun setSearchOpen(open: Boolean) {
        searchOpen = open
        applyBlur()
    }

    private fun applyBlur() {
        val blur = searchOpen && windowManager.isCrossWindowBlurEnabled
        if (blur) window.addFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
        window.attributes = window.attributes.also { it.blurBehindRadius = if (blur) BLUR_RADIUS else 0 }
    }

    private fun uninstall(app: AppEntry) {
        // For the app's own profile: the same app can be in the work profile
        // and the personal one, and only the one the tile stands for goes.
        val intent = Intent(Intent.ACTION_DELETE, Uri.fromParts("package", app.component.packageName, app.component.className))
            .putExtra(Intent.EXTRA_USER, app.user)
        runCatching { startActivity(intent) }
    }

    companion object {
        private const val BLUR_RADIUS = 60
    }
}
