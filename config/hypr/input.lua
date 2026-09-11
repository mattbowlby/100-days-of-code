-- Touch-first input. Overrides default/hypr/input.lua, which assumes a
-- keyboard, a pointer and a touchpad -- this device has none of the three.

local device = require("hypr.device")

-- A workspace swipe should complete about a third of the way across the panel.
-- Hyprland's default 300 was chosen for a desktop; on this 360px logical
-- portrait surface it is 83% of the width, which no thumb travels.
local swipe_distance = math.max(80, math.floor((device.logical_width or 360) / 3))

hl.config({
  input = {
    -- There is no cursor to follow, and touch-emulated motion would otherwise
    -- steal focus on every tap.
    follow_mouse = 0,

    touchdevice = {
      enabled = true,

      -- Bind the digitiser to the panel by name. Unbound, it maps across the
      -- whole layout, so touches land offset the moment a second output shows
      -- up (a dock, a cast).
      output = device.output,

      -- The digitiser is laminated to the panel, so it carries the panel's
      -- mounting rotation.
      transform = device.transform,
    },
  },

  misc = {
    -- The desktop wakes the display on any keypress. Here the only key is
    -- power, which belongs to the lock/DPMS path rather than to input.
    key_press_enables_dpms = device.has_keyboard,
    mouse_move_enables_dpms = false,
  },

  -- Horizontal touch swipe between workspaces is the phone's app switcher.
  --
  -- This is the legacy gestures:: section, and it is deliberate. Hyprland
  -- 0.56.2 enforces `fingers >= 2` on the current hl.gesture() keyword
  -- (verified: `hyprctl eval 'hl.gesture({ fingers = 1, ... })'` answers
  -- `value 1 is less than the minimum of 2`), so the new API cannot express a
  -- one-finger swipe. A phone swipe is one finger. workspace_swipe_touch is
  -- the only path that reaches the digitiser, and it still exists here even
  -- though the master `workspace_swipe` toggle no longer does.
  gestures = {
    workspace_swipe_touch = true,
    workspace_swipe_distance = swipe_distance,
    workspace_swipe_cancel_ratio = 0.3,

    -- Swiping past the last workspace on a desktop makes a new one. On a phone
    -- that is an accidental empty screen with no keyboard shortcut to escape it.
    workspace_swipe_create_new = false,
  },
})
