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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

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
// glow of its accent, the time large with the date under it, and a frosted
// card -- the phone's tile plate, rim and corners -- with what is playing.
// Side by side on a wide screen, stacked on a tall one (Volvo's portrait
// display). Laid out in the area Android Auto keeps clear of its own bars.
// Text is large and there is little of it: this is read at a glance, while
// driving.
object Dashboard {
    fun draw(canvas: Canvas, width: Int, height: Int, area: Rect, state: DashboardState) {
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

        val box = if (area.isEmpty) Rect(0, 0, width, height) else area
        // Sizes follow the shorter side, so a tall screen's text is not huge.
        val unit = minOf(box.width(), box.height()).toFloat()
        val pad = unit * 0.08f
        val inner = RectF(box.left + pad, box.top + pad, box.right - pad, box.bottom - pad)
        val tall = box.height() > box.width()

        val clock: RectF
        val card: RectF
        if (tall) {
            clock = RectF(inner.left, inner.top, inner.right, inner.top + inner.height() * 0.42f)
            card = RectF(inner.left, clock.bottom + pad, inner.right, minOf(inner.bottom, clock.bottom + pad + unit * 0.5f))
        } else {
            val split = inner.left + inner.width() * 0.48f
            clock = RectF(inner.left, inner.top, split - pad, inner.bottom)
            card = RectF(split, inner.top + inner.height() * 0.12f, inner.right, inner.bottom - inner.height() * 0.12f)
        }

        drawClock(canvas, clock, unit, fg, state)
        drawCard(canvas, card, bg, fg, state)
    }

    private fun drawClock(canvas: Canvas, box: RectF, unit: Float, fg: Int, state: DashboardState) {
        val locale = Locale.getDefault()
        val skeleton = if (state.use24Hour) "Hm" else "hma"
        val format = SimpleDateFormat(android.text.format.DateFormat.getBestDateTimePattern(locale, skeleton), locale)
        val time = format.format(state.now)

        // Sized for the widest time this format can show, not the current one,
        // so the clock does not change size from one minute to the next.
        val timePaint = text(fg, unit * 0.3f, light = true)
        val widest = widestTimes().map { format.format(it) }.maxBy { timePaint.measureText(it) }
        fit(timePaint, widest, box.width())
        val datePaint = text(withAlpha(fg, 0.75f), unit * 0.08f)
        val dateFormat = SimpleDateFormat(android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEEMMMMd"), locale)
        val date = ellipsize(dateFormat.format(state.now), datePaint, box.width())

        val block = timePaint.textSize + datePaint.textSize * 1.6f
        val timeY = box.centerY() - block / 2 + timePaint.textSize * 0.85f
        canvas.drawText(time, box.left, timeY, timePaint)
        canvas.drawText(date, box.left, timeY + datePaint.textSize * 1.6f, datePaint)
    }

    private fun drawCard(canvas: Canvas, card: RectF, bg: Int, fg: Int, state: DashboardState) {
        val radius = card.height() * 0.16f
        canvas.drawRoundRect(card, radius, radius, fill(withAlpha(bg, 0.45f)))
        canvas.drawRoundRect(card, radius, radius, fill(withAlpha(fg, 0.06f)))
        canvas.drawRoundRect(card, radius, radius, stroke(withAlpha(fg, 0.18f), maxOf(1f, card.height() * 0.006f)))

        val cardPad = card.height() * 0.14f
        val textWidth = card.width() - cardPad * 2
        val left = card.left + cardPad
        val label = text(withAlpha(fg, 0.65f), card.height() * 0.09f)
        canvas.drawText(ellipsize(if (state.playing) "NOW PLAYING" else "MUSIC", label, textWidth), left, card.top + cardPad + label.textSize, label)

        if (!state.mediaAllowed) {
            val hint = text(withAlpha(fg, 0.85f), card.height() * 0.085f)
            val lines = listOf("To see what's playing, allow", "notification access for", "Omarchy Home on your phone.")
            lines.forEachIndexed { i, line ->
                canvas.drawText(ellipsize(line, hint, textWidth), left, card.centerY() + hint.textSize * (i * 1.35f - 0.4f), hint)
            }
            return
        }

        val titlePaint = text(fg, card.height() * 0.16f, bold = true)
        val artistPaint = text(withAlpha(fg, 0.75f), card.height() * 0.11f)
        val titleY = card.centerY() + titlePaint.textSize * 0.35f
        if (state.title == null) {
            canvas.drawText(ellipsize("Nothing playing", titlePaint, textWidth), left, titleY, titlePaint)
            return
        }
        canvas.drawText(ellipsize(state.title, titlePaint, textWidth), left, titleY, titlePaint)
        state.artist?.let {
            canvas.drawText(ellipsize(it, artistPaint, textWidth), left, titleY + artistPaint.textSize * 1.5f, artistPaint)
        }
    }

    // The widest times there are: two-digit hours, 8s for minutes, in the
    // morning and the afternoon (12:58 is widest in a 12-hour clock, 23:58 in
    // a 24-hour one).
    private fun widestTimes(): List<Date> = listOf(
        java.util.GregorianCalendar(2026, 0, 1, 12, 58).time,
        java.util.GregorianCalendar(2026, 0, 1, 23, 58).time,
        java.util.GregorianCalendar(2026, 0, 1, 10, 58).time,
    )

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
        TextUtils.ellipsize(text, paint, maxOf(0f, width), TextUtils.TruncateAt.END).toString()

    private fun withAlpha(color: Int, alpha: Float): Int =
        (Math.round(alpha.coerceIn(0f, 1f) * 255) shl 24) or (color and 0x00FFFFFF)
}
