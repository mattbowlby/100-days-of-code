package dev.omarchyphone.launcher

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bluetooth
import androidx.compose.material.icons.rounded.BrightnessMedium
import androidx.compose.material.icons.rounded.FlashlightOn
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.automirrored.rounded.VolumeOff
import androidx.compose.material.icons.automirrored.rounded.VolumeUp
import androidx.compose.material.icons.rounded.Wifi
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// The control panel, iOS's control centre on the Linux port's design: a
// frosted card dropped from the top with a row of tiles in the one app shape
// -- Wi-Fi, Bluetooth, flashlight, settings -- and brightness and volume
// sliders a full row wide under them. A tap off the card closes it.
@Composable
fun ControlPanel(controls: Controls, theme: OmarchyTheme, tile: Dp, onClose: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(theme.background.copy(alpha = 0.35f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClose),
        contentAlignment = Alignment.TopCenter,
    ) {
        val gap = 16.dp
        val shape = RoundedCornerShape(tile * 0.27f + gap / 2)
        Column(
            Modifier
                .padding(16.dp)
                .widthIn(max = 420.dp)
                .frosted(theme, shape)
                // Taps on the card are not taps away.
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
                .padding(gap),
            verticalArrangement = Arrangement.spacedBy(gap),
        ) {
            // Centred: a phone with no flash has three tiles, not four.
            Row(Modifier.align(Alignment.CenterHorizontally), horizontalArrangement = Arrangement.spacedBy(gap)) {
                ControlTile(Icons.Rounded.Wifi, "Wi-Fi", tile, theme, onClick = { onClose(); controls.openWifi() })
                ControlTile(Icons.Rounded.Bluetooth, "Bluetooth", tile, theme, onClick = { onClose(); controls.openBluetooth() })
                if (controls.hasTorch) {
                    ControlTile(Icons.Rounded.FlashlightOn, "Flashlight", tile, theme, active = controls.torchOn, onClick = controls::toggleTorch)
                }
                ControlTile(Icons.Rounded.Settings, "Settings", tile, theme, onClick = { onClose(); controls.openSettings() })
            }
            val rowWidth = tile * 4 + gap * 3
            LevelSlider(
                icon = Icons.Rounded.BrightnessMedium,
                value = if (controls.canSetBrightness) controls.brightness else 0f,
                theme = theme,
                width = rowWidth,
                height = tile * 0.62f,
                radius = tile * 0.27f,
                minimum = Controls.BRIGHTNESS_FLOOR,
                hint = when {
                    !controls.canSetBrightness -> "Tap to allow brightness"
                    controls.autoBrightness -> "Auto"
                    else -> null
                },
                // Only the permission hint turns the slider into a button.
                blocking = !controls.canSetBrightness,
                onMoved = { if (controls.canSetBrightness) controls.changeBrightness(it) else controls.askForBrightness() },
            )
            LevelSlider(
                icon = if (controls.volume == 0f) Icons.AutoMirrored.Rounded.VolumeOff else Icons.AutoMirrored.Rounded.VolumeUp,
                value = controls.volume,
                theme = theme,
                width = rowWidth,
                height = tile * 0.62f,
                radius = tile * 0.27f,
                onMoved = controls::changeVolume,
            )
        }
    }
}

// A tile in the one app shape with a glyph where an app has its icon, and its
// name under it. Lit (the theme's accent) while what it controls is on.
@Composable
private fun ControlTile(
    glyph: ImageVector,
    label: String,
    size: Dp,
    theme: OmarchyTheme,
    active: Boolean = false,
    onClick: () -> Unit,
) {
    val shape = tileShape(size)
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier
                .size(size)
                .clip(shape)
                .background(if (active) theme.accent.copy(alpha = 0.85f) else theme.background.copy(alpha = 0.32f))
                .background(theme.foreground.copy(alpha = 0.08f))
                .border(1.dp, theme.foreground.copy(alpha = 0.22f), shape)
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                glyph,
                contentDescription = label,
                tint = if (active) theme.background else theme.foreground,
                modifier = Modifier.size(size * 0.45f),
            )
        }
        Text(
            label,
            modifier = Modifier.width(size + 12.dp).padding(top = 4.dp),
            style = TextStyle(color = theme.foreground, fontSize = 11.sp),
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

// A level from 0 to 1 on the tiles' frosted plate, filled from the start in
// the theme's foreground, its icon at the start. Drag along it, or tap a point
// on it. With a hint set it shows the hint and a tap asks instead.
@Composable
private fun LevelSlider(
    icon: ImageVector,
    value: Float,
    theme: OmarchyTheme,
    width: Dp,
    height: Dp,
    radius: Dp,
    minimum: Float = 0f,
    hint: String? = null,
    blocking: Boolean = false,
    onMoved: (Float) -> Unit,
) {
    val shape = RoundedCornerShape(radius)
    var dragging by remember { mutableStateOf(false) }
    var dragLevel by remember { mutableFloatStateOf(0f) }
    val shown = if (dragging) dragLevel else value
    BoxWithConstraints(
        Modifier
            .width(width)
            .height(height)
            .clip(shape)
            .background(theme.background.copy(alpha = 0.32f))
            .background(theme.foreground.copy(alpha = 0.08f))
            .border(1.dp, theme.foreground.copy(alpha = 0.22f), shape)
            .pointerInput(blocking) {
                fun level(x: Float) = (x / size.width).coerceIn(minimum, 1f)
                detectTapGestures { onMoved(level(it.x)) }
            }
            .pointerInput(blocking) {
                fun level(x: Float) = (x / size.width).coerceIn(minimum, 1f)
                if (blocking) return@pointerInput
                detectHorizontalDragGestures(
                    onDragStart = { dragging = true; dragLevel = level(it.x); onMoved(dragLevel) },
                    onDragEnd = { dragging = false },
                    onDragCancel = { dragging = false },
                    onHorizontalDrag = { change, _ -> dragLevel = level(change.position.x); onMoved(dragLevel) },
                )
            },
    ) {
        val fillWidth = if (shown > 0f) maxOf(radius * 2, maxWidth * shown) else 0.dp
        Box(
            Modifier
                .fillMaxHeight()
                .width(fillWidth)
                .clip(shape)
                .background(theme.foreground.copy(alpha = 0.85f)),
        )
        // The icon centred in the slider's first square, as on the Linux port;
        // dark once the fill passes its middle, light before.
        val iconSize = height * 0.45f
        Row(Modifier.fillMaxSize().padding(start = (height - iconSize) / 2, end = height * 0.3f), verticalAlignment = Alignment.CenterVertically) {
            val onFill = fillWidth > height / 2
            Icon(
                icon,
                contentDescription = null,
                tint = if (onFill) theme.background else theme.foreground,
                modifier = Modifier.size(iconSize),
            )
            if (hint != null) {
                Text(
                    hint,
                    modifier = Modifier.fillMaxWidth().padding(start = 8.dp),
                    style = TextStyle(color = theme.foreground.copy(alpha = 0.8f), fontSize = 13.sp),
                )
            }
        }
    }
}
