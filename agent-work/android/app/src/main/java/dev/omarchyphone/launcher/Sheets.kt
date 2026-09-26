package dev.omarchyphone.launcher

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Apps matching a query: names starting with it first, then names with a
// word starting with it, then names containing it anywhere; alphabetical
// within each. Empty, it lists every app, as iOS's search does before typing.
fun searchApps(apps: List<AppEntry>, query: String): List<AppEntry> {
    val q = query.trim().lowercase()
    if (q.isEmpty()) return apps
    fun rank(app: AppEntry): Int {
        val name = app.label.lowercase()
        return when {
            name.startsWith(q) -> 0
            name.split(' ', '-', '.', '_').any { it.startsWith(q) } -> 1
            name.contains(q) -> 2
            else -> -1
        }
    }
    return apps.map { it to rank(it) }
        .filter { it.second >= 0 }
        .sortedWith(compareBy({ it.second }, { it.first.label.lowercase() }))
        .map { it.first }
}

// Search, dropped from the top: a field with the keyboard up and the matches
// under it on the home screen's tiles. Enter opens the first match; a tap off
// the sheet closes it. Back closes it too (HomeActivity).
@Composable
fun SearchSheet(
    apps: List<AppEntry>,
    theme: OmarchyTheme,
    tile: Dp,
    onLaunch: (AppEntry) -> Unit,
    onClose: () -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val results = remember(apps, query) { searchApps(apps, query) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { focus.requestFocus() }

    Box(
        Modifier
            .fillMaxSize()
            .background(theme.background.copy(alpha = 0.35f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClose)
            .imePadding(),
        contentAlignment = Alignment.TopCenter,
    ) {
        val shape = RoundedCornerShape(tile * 0.27f + 8.dp)
        Column(
            Modifier
                .padding(16.dp)
                .widthIn(max = 480.dp)
                .fillMaxWidth()
                .frosted(theme, shape, alpha = 0.72f)
                // Taps on the sheet are not taps away.
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
                .padding(12.dp),
        ) {
            val fieldShape = RoundedCornerShape(tile * 0.27f)
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .clip(fieldShape)
                    .background(theme.foreground.copy(alpha = 0.1f))
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("⌕", style = TextStyle(color = theme.foreground.copy(alpha = 0.7f), fontSize = 18.sp))
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f)) {
                    if (query.isEmpty()) {
                        Text("Search", style = TextStyle(color = theme.foreground.copy(alpha = 0.6f), fontSize = 16.sp))
                    }
                    BasicTextField(
                        value = query,
                        onValueChange = { query = it },
                        singleLine = true,
                        textStyle = TextStyle(color = theme.foreground, fontSize = 16.sp),
                        cursorBrush = SolidColor(theme.accent),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Go),
                        keyboardActions = KeyboardActions(onGo = { results.firstOrNull()?.let(onLaunch) }),
                        modifier = Modifier.fillMaxWidth().focusRequester(focus),
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                items(results, key = { it.key }) { app ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(fieldShape)
                            .clickable { onLaunch(app) }
                            .padding(vertical = 4.dp, horizontal = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        AppIcon(app, tile * 0.7f, theme)
                        Spacer(Modifier.width(12.dp))
                        Text(app.label, style = TextStyle(color = theme.foreground, fontSize = 16.sp), maxLines = 1)
                    }
                }
            }
        }
    }
}

// Omarchy's themes, each with its colours as swatches; the current one is
// marked. A tap switches at once; a tap off the sheet closes it.
@Composable
fun ThemePicker(current: OmarchyTheme, onPick: (OmarchyTheme) -> Unit, onClose: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(current.background.copy(alpha = 0.35f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClose),
        contentAlignment = Alignment.BottomCenter,
    ) {
        val shape = RoundedCornerShape(24.dp)
        Column(
            Modifier
                .padding(16.dp)
                .widthIn(max = 480.dp)
                .fillMaxWidth()
                .frosted(current, shape, alpha = 0.8f)
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
                .padding(12.dp),
        ) {
            Text(
                "Theme",
                style = TextStyle(color = current.foreground, fontSize = 18.sp),
                modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
            )
            LazyColumn(Modifier.height(360.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                items(omarchyThemes, key = { it.id }) { theme ->
                    val selected = theme.id == current.id
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (selected) current.foreground.copy(alpha = 0.12f) else current.background.copy(alpha = 0f))
                            .clickable { onPick(theme) }
                            .padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        for (swatch in listOf(theme.background, theme.foreground, theme.accent)) {
                            Box(
                                Modifier
                                    .padding(end = 4.dp)
                                    .size(18.dp)
                                    .clip(CircleShape)
                                    .background(swatch)
                                    .border(1.dp, current.foreground.copy(alpha = 0.3f), CircleShape),
                            )
                        }
                        Spacer(Modifier.width(8.dp))
                        Text(theme.name, style = TextStyle(color = current.foreground, fontSize = 16.sp), modifier = Modifier.weight(1f))
                        if (selected) Text("✓", style = TextStyle(color = current.accent, fontSize = 16.sp))
                    }
                }
            }
        }
    }
}
