package dev.omarchyphone.launcher.drive

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.text.format.DateFormat
import androidx.car.app.AppManager
import androidx.car.app.CarAppService
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.validation.HostValidator
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import dev.omarchyphone.launcher.LauncherSettings
import dev.omarchyphone.launcher.R
import dev.omarchyphone.launcher.omarchyThemes
import dev.omarchyphone.launcher.themeById
import java.util.Date

// Omarchy Drive: what Android Auto starts on the car's screen when the phone
// is plugged in (or connected wirelessly). Android Auto lets only navigation
// apps draw their own screen, so it is declared one; it draws a dashboard
// rather than a map.
class DriveService : CarAppService() {
    // Android Auto itself, Google's; any host while debugging.
    override fun createHostValidator(): HostValidator =
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        else HostValidator.Builder(applicationContext)
            .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
            .build()

    override fun onCreateSession(): Session = DriveSession()
}

class DriveSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen = DashboardScreen(carContext)
}

// The dashboard: drawn onto the car's screen surface, with an action strip of
// big buttons -- play or pause, next track, next theme -- that Android Auto
// draws in its own style at the screen's edge.
class DashboardScreen(carContext: CarContext) : Screen(carContext), DefaultLifecycleObserver {
    private val settings = LauncherSettings(carContext)
    private val main = Handler(Looper.getMainLooper())
    private val nowPlaying = NowPlaying(carContext) { redrawAndRefreshButtons() }

    private var surface: SurfaceContainer? = null
    private var visible = Rect()
    private var lastPlaying: Boolean? = null

    // Once a minute is enough for a clock without seconds; aligned to the
    // minute so it turns over when the minute does.
    private val tick = object : Runnable {
        override fun run() {
            draw()
            main.postDelayed(this, 60_000L - System.currentTimeMillis() % 60_000L)
        }
    }

    private val surfaceCallback = object : SurfaceCallback {
        override fun onSurfaceAvailable(container: SurfaceContainer) {
            surface = container
            draw()
        }

        override fun onVisibleAreaChanged(visibleArea: Rect) {
            visible = Rect(visibleArea)
            draw()
        }

        override fun onSurfaceDestroyed(container: SurfaceContainer) {
            surface = null
        }
    }

    init {
        lifecycle.addObserver(this)
    }

    override fun onCreate(owner: LifecycleOwner) {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(surfaceCallback)
    }

    override fun onStart(owner: LifecycleOwner) {
        nowPlaying.start()
        main.post(tick)
    }

    override fun onStop(owner: LifecycleOwner) {
        main.removeCallbacks(tick)
        nowPlaying.stop()
    }

    override fun onGetTemplate(): Template {
        val buttons = ActionStrip.Builder()
        if (nowPlaying.allowed) {
            buttons.addAction(action(if (nowPlaying.playing) R.drawable.ic_drive_pause else R.drawable.ic_drive_play) {
                nowPlaying.playPause()
            })
            buttons.addAction(action(R.drawable.ic_drive_next) { nowPlaying.next() })
        }
        buttons.addAction(action(R.drawable.ic_drive_theme) { nextTheme() })
        return NavigationTemplate.Builder()
            .setActionStrip(buttons.build())
            .build()
    }

    private fun action(icon: Int, onClick: () -> Unit) = Action.Builder()
        .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, icon)).build())
        .setOnClickListener(onClick)
        .build()

    // The phone's own theme setting, so the home screen and the car change
    // together.
    private fun nextTheme() {
        val index = omarchyThemes.indexOfFirst { it.id == settings.themeId }
        settings.setTheme(omarchyThemes[(index + 1) % omarchyThemes.size].id)
        draw()
    }

    // The buttons only change between play and pause (or appear once media
    // access is granted): the template is rebuilt only then, as Android Auto
    // limits how often a screen may refresh.
    private fun redrawAndRefreshButtons() {
        draw()
        val shown = if (nowPlaying.allowed) nowPlaying.playing else null
        if (shown != lastPlaying) {
            lastPlaying = shown
            invalidate()
        }
    }

    private fun draw() {
        val container = surface ?: return
        val target = container.surface ?: return
        if (!target.isValid) return
        val canvas = runCatching { target.lockCanvas(null) }.getOrNull() ?: return
        try {
            Dashboard.draw(
                canvas, container.width, container.height, visible,
                DashboardState(
                    theme = themeById(settings.themeId),
                    now = Date(),
                    use24Hour = DateFormat.is24HourFormat(carContext),
                    title = nowPlaying.title,
                    artist = nowPlaying.artist,
                    playing = nowPlaying.playing,
                    mediaAllowed = nowPlaying.allowed,
                ),
            )
        } finally {
            target.unlockCanvasAndPost(canvas)
        }
    }
}
