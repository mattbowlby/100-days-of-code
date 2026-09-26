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
// the phone's home app (Settings > Apps > Default apps > Home app).
class HomeActivity : ComponentActivity() {
    private lateinit var repository: AppRepository
    private lateinit var settings: LauncherSettings

    // Counts Home presses while the home screen is already showing, which
    // HomeScreen answers by going back to the first page.
    private var homePresses by mutableIntStateOf(0)
    private var searchOpen = false

    // Back closes search; with nothing open, a home screen has nowhere to go
    // back to, so Back is taken and does nothing.
    private val back = object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {
            if (searchOpen) homePresses++
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        repository = AppRepository(this)
        settings = LauncherSettings(this)
        onBackPressedDispatcher.addCallback(this, back)

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
            )
        }
    }

    override fun onStart() {
        super.onStart()
        repository.start()
    }

    override fun onStop() {
        repository.stop()
        super.onStop()
    }

    // Home pressed with the home screen already in front.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (Intent.ACTION_MAIN == intent.action && hasWindowFocus()) homePresses++
    }

    // The wallpaper frosts over behind search, as the home screen does on iOS,
    // where the phone supports blurring behind a window (Samsung's flagships
    // do; the setting can also be off to save battery). Without it the sheet's
    // own tint still separates it.
    private fun setSearchOpen(open: Boolean) {
        searchOpen = open
        if (!windowManager.isCrossWindowBlurEnabled) return
        window.attributes = window.attributes.also {
            if (open) {
                window.addFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
                it.blurBehindRadius = BLUR_RADIUS
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
                it.blurBehindRadius = 0
            }
        }
    }

    private fun uninstall(app: AppEntry) {
        val intent = Intent(Intent.ACTION_DELETE, Uri.fromParts("package", app.component.packageName, null))
        runCatching { startActivity(intent) }
    }

    companion object {
        private const val BLUR_RADIUS = 60
    }
}
