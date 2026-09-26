package dev.omarchyphone.launcher

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// The one app shape: a rounded square with corners at 0.27 of its side, as on
// the Omarchy phone port. An adaptive icon fills it edge to edge; any other
// icon sits on the frosted plate -- the theme's background, see-through, with a
// hairline rim -- so a circle, a square and a bare logo all come out the same
// shape.
fun tileShape(size: Dp) = RoundedCornerShape(size * 0.27f)

@Composable
fun AppIcon(app: AppEntry, size: Dp, theme: OmarchyTheme, modifier: Modifier = Modifier) {
    val shape = tileShape(size)
    val rim = BorderStroke(1.dp, theme.foreground.copy(alpha = 0.22f))
    if (app.fullBleed) {
        Image(
            bitmap = app.icon,
            contentDescription = app.label,
            contentScale = ContentScale.Crop,
            modifier = modifier.size(size).clip(shape).border(rim, shape),
        )
    } else {
        Box(
            modifier = modifier
                .size(size)
                .clip(shape)
                .background(theme.background.copy(alpha = 0.32f))
                .background(theme.foreground.copy(alpha = 0.08f))
                .border(rim, shape),
            contentAlignment = Alignment.Center,
        ) {
            Image(
                bitmap = app.icon,
                contentDescription = app.label,
                modifier = Modifier.size(size * 0.72f),
            )
        }
    }
}

// An icon with its name under it, as on the home screen's pages. The label is
// the theme's foreground with a soft shadow, readable over any wallpaper.
@Composable
fun AppTile(app: AppEntry, size: Dp, theme: OmarchyTheme, showLabel: Boolean = true, modifier: Modifier = Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        AppIcon(app, size, theme)
        if (showLabel) {
            Text(
                text = app.label,
                modifier = Modifier.width(size + 16.dp).padding(top = 5.dp),
                style = labelStyle(theme),
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

fun labelStyle(theme: OmarchyTheme) = TextStyle(
    color = theme.foreground,
    fontSize = 12.sp,
    shadow = Shadow(color = Color.Black.copy(alpha = 0.55f), blurRadius = 6f),
)

// The frosted panel behind the dock, the search sheet and the theme picker.
fun Modifier.frosted(theme: OmarchyTheme, shape: RoundedCornerShape, alpha: Float = 0.45f) = this
    .clip(shape)
    .background(theme.background.copy(alpha = alpha))
    .border(BorderStroke(1.dp, theme.foreground.copy(alpha = 0.16f)), shape)
