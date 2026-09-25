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
