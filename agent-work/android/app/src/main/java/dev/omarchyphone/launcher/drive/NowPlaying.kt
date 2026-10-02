package dev.omarchyphone.launcher.drive

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService

// Only here so the user can grant notification access, which is what Android
// asks of an app that wants to see other apps' media sessions. It reads no
// notifications.
class MediaAccessService : NotificationListenerService()

// What is playing now, from whichever app is playing it (Spotify, YouTube
// Music, Samsung Music...), and its controls. Needs notification access; until
// it is granted, `allowed` is false and nothing is read.
class NowPlaying(private val context: Context, private val onChange: () -> Unit) {
    private val sessions = context.getSystemService(MediaSessionManager::class.java)
    private val listener = ComponentName(context, MediaAccessService::class.java)
    private val main = Handler(Looper.getMainLooper())

    var title: String? = null
        private set
    var artist: String? = null
        private set
    var playing = false
        private set
    var allowed = false
        private set

    private var controller: MediaController? = null

    private val callback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) = read()
        override fun onPlaybackStateChanged(state: PlaybackState?) = read()
        override fun onSessionDestroyed() = pick(currentSessions())
    }

    private val sessionsChanged = MediaSessionManager.OnActiveSessionsChangedListener { list ->
        pick(list.orEmpty())
    }

    fun start() {
        allowed = isAllowed()
        if (!allowed) {
            onChange()
            return
        }
        runCatching { sessions.addOnActiveSessionsChangedListener(sessionsChanged, listener, main) }
        pick(currentSessions())
    }

    fun stop() {
        runCatching { sessions.removeOnActiveSessionsChangedListener(sessionsChanged) }
        controller?.unregisterCallback(callback)
        controller = null
    }

    fun playPause() {
        val c = controller ?: return
        if (playing) c.transportControls.pause() else c.transportControls.play()
    }

    fun next() {
        controller?.transportControls?.skipToNext()
    }

    private fun isAllowed(): Boolean {
        val enabled = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners") ?: return false
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == listener }
    }

    private fun currentSessions(): List<MediaController> =
        runCatching { sessions.getActiveSessions(listener) }.getOrDefault(emptyList())

    // The one playing, else the most recent (Android lists the most recently
    // active first).
    private fun pick(list: List<MediaController>) {
        val chosen = list.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING } ?: list.firstOrNull()
        if (chosen?.sessionToken != controller?.sessionToken) {
            controller?.unregisterCallback(callback)
            controller = chosen
            chosen?.registerCallback(callback, main)
        }
        read()
    }

    private fun read() {
        val c = controller
        val metadata = c?.metadata
        title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
        artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
        playing = c?.playbackState?.state == PlaybackState.STATE_PLAYING
        onChange()
    }
}
