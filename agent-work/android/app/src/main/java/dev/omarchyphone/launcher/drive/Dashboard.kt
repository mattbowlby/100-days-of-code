package dev.omarchyphone.launcher.drive

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.TextPaint
import android.text.TextUtils
import androidx.compose.ui.graphics.toArgb
import dev.omarchyphone.launcher.OmarchyTheme
import java.text.DateFormat
import java.util.Date

// What the dashboard shows, read when it is drawn.
data class DashboardState(
    val theme: OmarchyTheme,
    val now: Date,
    val use24Hour: Boolean,
    val title: String?,
    val artist: String?,
    val playing: Boolean,
    val mediaAllowed: Boolean,
)

// Draws Omarchy Drive on the car's screen: the theme's background with a soft
// glow of its accent, the time large and the date under it on the left, and
// on the right a frosted card -- the phone's tile plate, rim and corners -- with
// what is playing. Sized from the area Android Auto leaves visible, so nothing
// sits under its own bars. Text is large and there is little of it: this is
// read at a glance, while driving.
object Dashboard {
    fun draw(canvas: Canvas, width: Int, height: Int, visible: Rect, state: DashboardState) {
        val theme = state.theme
        val bg = theme.background.toArgb()
        val fg = theme.foreground.toArgb()

        canvas.drawColor(bg)
        val glow = Paint().apply {
            shader = RadialGradient(
                width * 0.85f, height * 0.15f, maxOf(width, height) * 0.7f,
                withAlpha(theme.accent.toArgb(), 0.22f), withAlpha(bg, 0f), Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), glow)

        val area = if (visible.isEmpty) Rect(0, 0, width, height) else visible
        val pad = area.height() * 0.08f
        val inner = RectF(area.left + pad, area.top + pad, area.right - pad, area.bottom - pad)
        val split = inner.left + inner.width() * 0.48f

        // The time and date.
        val time = DateFormat.getTimeInstance(DateFormat.SHORT).let {
            if (state.use24Hour) java.text.SimpleDateFormat("HH:mm").format(state.now) else it.format(state.now)
        }
        val timePaint = text(fg, inner.height() * 0.34f, light = true)
        fit(timePaint, time, split - inner.left - pad)
        val timeY = inner.centerY() + timePaint.textSize * 0.1f
        canvas.drawText(time, inner.left, timeY, timePaint)
        val datePaint = text(withAlpha(fg, 0.75f), inner.height() * 0.09f)
        val date = DateFormat.getDateInstance(DateFormat.FULL).format(state.now)
        canvas.drawText(ellipsize(date, datePaint, split - inner.left - pad), inner.left, timeY + datePaint.textSize * 1.6f, datePaint)

        // The now-playing card.
        val card = RectF(split, inner.top + inner.height() * 0.12f, inner.right, inner.bottom - inner.height() * 0.12f)
        val radius = card.height() * 0.16f
        canvas.drawRoundRect(card, radius, radius, fill(withAlpha(bg, 0.45f)))
        canvas.drawRoundRect(card, radius, radius, fill(withAlpha(fg, 0.06f)))
        canvas.drawRoundRect(card, radius, radius, stroke(withAlpha(fg, 0.18f), maxOf(1f, card.height() * 0.006f)))

        val cardPad = card.height() * 0.14f
        val textWidth = card.width() - cardPad * 2
        val label = text(withAlpha(fg, 0.65f), card.height() * 0.09f)
        canvas.drawText(if (state.playing) "NOW PLAYING" else "MUSIC", card.left + cardPad, card.top + cardPad + label.textSize, label)

        if (!state.mediaAllowed) {
            val hint = text(withAlpha(fg, 0.85f), card.height() * 0.085f)
            val lines = listOf("To see what's playing, allow", "notification access for", "Omarchy Home on your phone.")
            lines.forEachIndexed { i, line ->
                canvas.drawText(ellipsize(line, hint, textWidth), card.left + cardPad, card.centerY() + hint.textSize * (i * 1.35f - 0.4f), hint)
            }
            return
        }

        val titlePaint = text(fg, card.height() * 0.16f, bold = true)
        val artistPaint = text(withAlpha(fg, 0.75f), card.height() * 0.11f)
        val title = state.title ?: "Nothing playing"
        canvas.drawText(ellipsize(title, titlePaint, textWidth), card.left + cardPad, card.centerY() + titlePaint.textSize * 0.35f, titlePaint)
        state.artist?.let {
            canvas.drawText(ellipsize(it, artistPaint, textWidth), card.left + cardPad, card.centerY() + titlePaint.textSize * 0.35f + artistPaint.textSize * 1.5f, artistPaint)
        }
    }

    private fun text(color: Int, size: Float, bold: Boolean = false, light: Boolean = false) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color
        textSize = size
        typeface = when {
            bold -> Typeface.create("sans-serif-medium", Typeface.NORMAL)
            light -> Typeface.create("sans-serif-light", Typeface.NORMAL)
            else -> Typeface.create("sans-serif", Typeface.NORMAL)
        }
    }

    private fun fill(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }

    private fun stroke(color: Int, width: Float) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color
        style = Paint.Style.STROKE
        strokeWidth = width
    }

    // Shrinks a paint's text size until the text fits a width.
    private fun fit(paint: TextPaint, text: String, width: Float) {
        val measured = paint.measureText(text)
        if (measured > width && measured > 0f) paint.textSize *= width / measured
    }

    private fun ellipsize(text: String, paint: TextPaint, width: Float): String =
        TextUtils.ellipsize(text, paint, width, TextUtils.TruncateAt.END).toString()

    private fun withAlpha(color: Int, alpha: Float): Int =
        (Math.round(alpha.coerceIn(0f, 1f) * 255) shl 24) or (color and 0x00FFFFFF)
}
