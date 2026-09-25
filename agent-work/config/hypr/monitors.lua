-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Panel geometry comes from the device profile: install/devices/<codename>.conf

local device = require("hypr.device")

-- GDK_SCALE only takes integers, and the desktop's hardcoded 2 under-scales GTK
-- apps on a ~400ppi panel, so round the panel's own scale to what it can express.
hl.env("GDK_SCALE", tostring(math.max(1, math.floor(device.scale + 0.5))))

-- A phone has exactly one built-in panel, so unlike the desktop's "" catch-all
-- this names the output and pins the mode. "preferred" guessed wrong on a DSI
-- panel is a garbled screen, not a slightly-off resolution.
hl.monitor({
  output = device.output,
  mode = device.mode,
  position = "auto",
  scale = device.scale,
  transform = device.transform,
})
