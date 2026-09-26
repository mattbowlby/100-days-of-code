package dev.omarchyphone.launcher

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// The one app shape: a rounded square with corners at 0.27 of its side, as on
// the Omarchy phone port. Every app sits on the same frosted plate -- the
// theme's background, see-through, lifted by a faint wash of its foreground
// and edged with a hairline -- with its icon at 0.64 of the side on top. An
// adaptive icon is clipped to the same rounded square; any other icon keeps
// the shape it came with, on the same plate.
fun tileShape(size: Dp) = RoundedCornerShape(size * 0.27f)

@Composable
fun AppIcon(app: AppEntry, size: Dp, theme: OmarchyTheme, pressed: Boolean = false, modifier: Modifier = Modifier) {
    val shape = tileShape(size)
    val scale by animateFloatAsState(if (pressed) 0.92f else 1f, tween(110), label = "press")
    Box(
        modifier = modifier
            .size(size)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clip(shape)
            .background(theme.background.copy(alpha = 0.32f))
            .background(theme.foreground.copy(alpha = if (pressed) 0.2f else 0.08f))
            .border(BorderStroke(1.dp, theme.foreground.copy(alpha = 0.22f)), shape),
        contentAlignment = Alignment.Center,
    ) {
        val inner = size * 0.64f
        Image(
            bitmap = app.icon,
            contentDescription = app.label,
            modifier = Modifier
                .size(inner)
                .then(if (app.adaptive) Modifier.clip(tileShape(inner)) else Modifier),
        )
    }
}

// An app's tile: its icon on the plate, with its name under it on the pages
// (not in the dock). A tap opens it; a long press asks for its menu. Pressed,
// the tile shrinks a little and its wash brightens, as on the Linux port.
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AppTile(
    app: AppEntry,
    size: Dp,
    theme: OmarchyTheme,
    showLabel: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Column(
        modifier = modifier.combinedClickable(
            interactionSource = interaction,
            indication = null,
            onClick = onClick,
            onLongClick = onLongClick,
        ),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        AppIcon(app, size, theme, pressed)
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

// The theme's foreground, haloed in its background so it reads over any
// wallpaper -- dark text in a light halo on a light theme, and the other way
// round on a dark one, as the Linux port outlines its labels.
fun labelStyle(theme: OmarchyTheme) = TextStyle(
    color = theme.foreground,
    fontSize = 12.sp,
    shadow = Shadow(color = theme.background.copy(alpha = 0.55f), blurRadius = 4f),
)

// The frosted panel behind the dock, the search sheet and the theme picker.
fun Modifier.frosted(theme: OmarchyTheme, shape: RoundedCornerShape, alpha: Float = 0.45f, rim: Float = 0.16f) = this
    .clip(shape)
    .background(theme.background.copy(alpha = alpha))
    .border(BorderStroke(1.dp, theme.foreground.copy(alpha = rim)), shape)
