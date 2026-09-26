-- Phone look'n'feel. Overrides default/hypr/looknfeel.lua, which is sized for a
-- pointer and for a screen with pixels to spare.

hl.config({
  general = {
    -- The desktop's 5px in, 10px out and 2px border spend 24 of this panel's
    -- 360 logical columns -- almost 7% of the width -- on chrome that no finger
    -- can use. A phone window is the screen.
    gaps_in = 0,
    gaps_out = 0,

    -- A border exists to be grabbed with a pointer. There is no pointer, and
    -- focus needs no marking when one window fills the display.
    border_size = 0,
  },
})

-- The workspace slide is the app-switch animation. It is the only feedback that
-- a touch swipe was understood and which way it went, so unlike the desktop --
-- where switching is instant and keyboard-driven -- it has to be on.
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })

-- The see-through look. Upstream ships blur off; the phone turns it on, because
-- its shell surfaces are drawn in low-alpha washes of the theme's colours and
-- rely on the blur to stay legible over any wallpaper.
--
-- Blur is global in Hyprland, so it reaches windows too, and upstream gives
-- every window 0.985/0.96 opacity (default/hypr/windows.lua) -- a blur pass
-- behind each app, which here is always full-screen: GPU time on every frame
-- for a translucency nobody can see past the edges of. So phone windows are
-- made opaque below, and the frost stays on the shell's own surfaces.
hl.config({
  decoration = {
    blur = {
      enabled = true,
      -- Few passes at a moderate size: most of the frosted look for a fraction
      -- of the fill rate. Each pass is a full-surface read on an Adreno 630.
      size = 8,
      passes = 2,
      vibrancy = 0.2,
      -- new_optimizations caches a background blur for tiled windows, which
      -- are opaque here; with xray off, the shell's layers blur what is really
      -- under them, live.
      new_optimizations = true,
      xray = false,
    },
  },
})

-- Blur behind the phone's own surfaces. ignore_alpha keeps the fully clear
-- parts of each surface -- the home screen between its tiles, the bar strip
-- the control centre leaves undimmed -- out of the blur. The control centre's
-- 0.35 scrim is above it, so everything behind the sheet is frosted on
-- purpose. 0.1 sits below every wash these surfaces draw with.
hl.layer_rule({
  match = { namespace = "^omarchy-phone-(bar|home|control|keyboard)$" },
  blur = true,
  ignore_alpha = 0.1,
})

-- Windows opaque; see above. Every window, not just the default-opacity tag:
-- apps that opt out of that tag upstream carry opacities of their own -- the
-- browser's is "1.0 0.985" (default/hypr/apps/browser.lua) -- and on a phone
-- the browser is the app most often open. Loaded after upstream's rules, and a
-- later matching rule wins, so this is the last word.
o.window(".*", { opacity = "1 1" })

-- The on-screen keyboard is drawn -- and takes touches -- above a session lock
-- (2 is "render and interact"; 1 would only draw it). Omarchy's lock asks for
-- a typed password, the lock surface keeps keyboard focus, and the keys this
-- keyboard injects go to the focused surface: so this is what lets a phone with
-- no hardware keyboard unlock. Only this one namespace: anything else above
-- the lock would be readable and usable by whoever holds the phone. Rules
-- match on namespace alone, so any client naming its surface this could draw
-- above the lock too (NOTES.md has the risk); a lock with its own keypad is
-- what retires this rule.
hl.layer_rule({
  match = { namespace = "^omarchy-phone-keyboard$" },
  above_lock = 2,
})
