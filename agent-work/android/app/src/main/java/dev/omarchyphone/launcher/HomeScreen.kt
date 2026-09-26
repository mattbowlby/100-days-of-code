package dev.omarchyphone.launcher

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.exclude
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MenuDefaults
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

// What the home screen needs from outside it: a way to start an app, show its
// info and uninstall it. HomeActivity passes these in.
class HomeActions(
    val launch: (AppEntry) -> Unit,
    val appInfo: (AppEntry) -> Unit,
    val uninstall: (AppEntry) -> Unit,
)

// Four across, as on iOS; the rows are however many fit.
private const val COLUMNS = 4
// Shortest side at or above this is an unfolded foldable (or a tablet):
// two pages side by side.
private val WIDE_SHORTEST_SIDE = 600.dp
// Space around the grid, the dots' row, and the gap between dock and edge.
private val GRID_PAD_V = 12.dp
private val DOTS = 24.dp
private val DOCK_MARGIN = 12.dp
// Between the dock's rim and its tiles, all round: the dock's corners are the
// tiles' plus this, so the two curves stay concentric.
private val DOCK_INSET = 12.dp

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HomeScreen(
    apps: List<AppEntry>,
    settings: LauncherSettings,
    actions: HomeActions,
    homePresses: Int,
    onSearchOpenChanged: (Boolean) -> Unit,
    controls: Controls? = null,
) {
    val theme = themeById(settings.themeId)
    var searching by remember { mutableStateOf(false) }
    var pickingTheme by remember { mutableStateOf(false) }
    var controlling by remember { mutableStateOf(false) }

    fun openControls() {
        controls?.refresh()
        controlling = controls != null
    }

    val byKey = remember(apps) { apps.associateBy { it.key } }
    // Only apps still installed count: a docked app that was uninstalled would
    // otherwise hold its slot, invisible and impossible to remove.
    val dockKeys = (settings.dockKeys ?: remember(apps) { settings.defaultDock() })
        .filter { it in byKey }
        .take(LauncherSettings.DOCK_SIZE)
    val dock = dockKeys.mapNotNull { byKey[it] }
    // Docked apps are not on the pages as well, as on iOS.
    val paged = remember(apps, dockKeys) { apps.filterNot { it.key in dockKeys } }

    fun setSearching(open: Boolean) {
        searching = open
        onSearchOpenChanged(open)
    }

    // Back closes whatever sheet is open, and only that. With none open it
    // falls through to HomeActivity, which keeps Back from leaving home.
    BackHandler(enabled = searching || pickingTheme || controlling) {
        setSearching(false)
        pickingTheme = false
        controlling = false
    }

    // The keyboard is left out: it covers the pages rather than squeezing
    // them, so the grid does not reflow each time search opens. The search
    // sheet makes room for it itself.
    BoxWithConstraints(
        Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing.exclude(WindowInsets.ime)),
    ) {
        val wide = min(maxWidth, maxHeight) >= WIDE_SHORTEST_SIDE
        val pageWidth = if (wide) maxWidth / 2 else maxWidth
        val pad = 20.dp
        val tile = min(64.dp, (pageWidth - pad * 2) / COLUMNS * 0.72f)
        val cellHeight = tile + 38.dp
        val dockHeight = tile + DOCK_INSET * 2
        val gridHeight = maxHeight - dockHeight - DOCK_MARGIN * 2 - DOTS - GRID_PAD_V * 2
        val rows = max(1, floor(gridHeight / cellHeight).toInt())
        val perPage = rows * COLUMNS
        val pages = remember(paged, perPage) { paged.chunked(perPage).ifEmpty { listOf(emptyList()) } }
        val spread = if (wide && pages.size > 1) 2 else 1
        val pagerState = rememberPagerState { ceil(pages.size / spread.toFloat()).toInt() }

        // Home pressed while home: back to the first page and out of any
        // sheet, as iOS does on a second press.
        LaunchedEffect(homePresses) {
            if (homePresses > 0) {
                setSearching(false)
                pickingTheme = false
                controlling = false
                pagerState.animateScrollToPage(0)
            }
        }

        Column(Modifier.fillMaxSize()) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    // Down on the pages opens search, as a swipe down on iOS's
                    // home screen does -- or, started near the top right, the
                    // control panel, where iOS keeps its control centre.
                    // Sideways stays the pager's.
                    .pointerInput(Unit) {
                        var dragged = 0f
                        var fromCorner = false
                        detectVerticalDragGestures(
                            onDragStart = { start ->
                                dragged = 0f
                                // The right two columns of the top row: a
                                // column edge, so no icon is split between the
                                // two gestures.
                                fromCorner = start.x > size.width / 2f && start.y < 96.dp.toPx()
                            },
                            onVerticalDrag = { _, dy -> dragged += dy },
                            onDragEnd = {
                                if (dragged > 56.dp.toPx()) {
                                    if (fromCorner && controls != null) openControls() else setSearching(true)
                                }
                            },
                        )
                    }
                    // A long press on the wallpaper, between apps: themes.
                    .combinedClickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = {},
                        onLongClick = { pickingTheme = true },
                    ),
            ) { index ->
                // A lone page on a wide screen sits in the middle, as on the
                // Linux port, rather than in the left half.
                Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.Center) {
                    for (s in 0 until spread) {
                        AppGrid(
                            apps = pages.getOrNull(index * spread + s) ?: emptyList(),
                            rows = rows,
                            tile = tile,
                            cellHeight = cellHeight,
                            theme = theme,
                            dockKeys = dockKeys,
                            settings = settings,
                            actions = actions,
                            homePresses = homePresses,
                            modifier = Modifier.width(pageWidth).padding(horizontal = pad, vertical = GRID_PAD_V),
                        )
                    }
                }
            }

            PageDots(pagerState, theme)

            Box(Modifier.fillMaxWidth().padding(DOCK_MARGIN), contentAlignment = Alignment.Center) {
                Dock(dock, tile, theme, dockKeys, settings, actions, homePresses, dockHeight)
            }
        }

        AnimatedVisibility(visible = searching, enter = fadeIn(), exit = fadeOut()) {
            SearchSheet(
                apps = apps,
                theme = theme,
                tile = tile,
                onLaunch = { app -> setSearching(false); actions.launch(app) },
                onClose = { setSearching(false) },
            )
        }

        if (controls != null) {
            AnimatedVisibility(visible = controlling, enter = fadeIn(), exit = fadeOut()) {
                ControlPanel(controls, theme, tile, onClose = { controlling = false })
            }
        }

        AnimatedVisibility(visible = pickingTheme, enter = fadeIn(), exit = fadeOut()) {
            ThemePicker(
                current = theme,
                onPick = { settings.setTheme(it.id) },
                onClose = { pickingTheme = false },
            )
        }
    }
}

// One page of apps: rows of four, top-aligned, spread evenly across the width.
@Composable
private fun AppGrid(
    apps: List<AppEntry>,
    rows: Int,
    tile: Dp,
    cellHeight: Dp,
    theme: OmarchyTheme,
    dockKeys: List<String>,
    settings: LauncherSettings,
    actions: HomeActions,
    homePresses: Int,
    modifier: Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.Top) {
        for (r in 0 until rows) {
            Row(Modifier.fillMaxWidth().height(cellHeight), horizontalArrangement = Arrangement.SpaceEvenly) {
                for (c in 0 until COLUMNS) {
                    val app = apps.getOrNull(r * COLUMNS + c)
                    Box(Modifier.weight(1f), contentAlignment = Alignment.TopCenter) {
                        if (app != null) {
                            LaunchableTile(app, tile, theme, dockKeys, settings, actions, homePresses, showLabel = true)
                        }
                    }
                }
            }
        }
    }
}

// A tile that opens its app on a tap and offers a menu on a long press: put
// it in or take it out of the dock, see its info, uninstall it. The menu is in
// the theme's colours, and closes on a Home press.
@Composable
private fun LaunchableTile(
    app: AppEntry,
    tile: Dp,
    theme: OmarchyTheme,
    dockKeys: List<String>,
    settings: LauncherSettings,
    actions: HomeActions,
    homePresses: Int,
    showLabel: Boolean,
) {
    var menu by remember { mutableStateOf(false) }
    LaunchedEffect(homePresses) { menu = false }
    val inDock = app.key in dockKeys
    val itemColors = MenuDefaults.itemColors(textColor = theme.foreground)
    Box {
        AppTile(
            app = app,
            size = tile,
            theme = theme,
            showLabel = showLabel,
            onClick = { actions.launch(app) },
            onLongClick = { menu = true },
        )
        DropdownMenu(
            expanded = menu,
            onDismissRequest = { menu = false },
            shape = RoundedCornerShape(tile * 0.27f),
            containerColor = theme.background,
        ) {
            if (inDock) {
                DropdownMenuItem(text = { Text("Remove from Dock") }, colors = itemColors, onClick = {
                    menu = false
                    settings.setDock(dockKeys - app.key)
                })
            } else if (dockKeys.size < LauncherSettings.DOCK_SIZE) {
                DropdownMenuItem(text = { Text("Add to Dock") }, colors = itemColors, onClick = {
                    menu = false
                    settings.setDock(dockKeys + app.key)
                })
            }
            DropdownMenuItem(text = { Text("App Info") }, colors = itemColors, onClick = { menu = false; actions.appInfo(app) })
            DropdownMenuItem(text = { Text("Uninstall") }, colors = itemColors, onClick = { menu = false; actions.uninstall(app) })
        }
    }
}

// The dock: a frosted panel with room for four apps, no labels, as on iOS and
// the Linux port -- sized to its four slots rather than the screen, lighter
// than the sheets, its corners concentric with the tiles'.
@Composable
private fun Dock(
    apps: List<AppEntry>,
    tile: Dp,
    theme: OmarchyTheme,
    dockKeys: List<String>,
    settings: LauncherSettings,
    actions: HomeActions,
    homePresses: Int,
    height: Dp,
) {
    val shape = RoundedCornerShape(tile * 0.27f + DOCK_INSET)
    val slot = tile + DOCK_INSET * 2
    Row(
        modifier = Modifier
            .width(slot * LauncherSettings.DOCK_SIZE)
            .height(height)
            .frosted(theme, shape, alpha = 0.28f, rim = 0.14f),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        for (app in apps) {
            LaunchableTile(app, tile, theme, dockKeys, settings, actions, homePresses, showLabel = false)
        }
    }
}

// One dot per page (or spread), the current one solid.
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PageDots(state: PagerState, theme: OmarchyTheme) {
    Row(
        modifier = Modifier.fillMaxWidth().height(DOTS),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (state.pageCount > 1) {
            for (i in 0 until state.pageCount) {
                Box(
                    Modifier
                        .padding(horizontal = 4.dp)
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(theme.foreground.copy(alpha = if (i == state.currentPage) 0.95f else 0.35f)),
                )
            }
        }
    }
}
