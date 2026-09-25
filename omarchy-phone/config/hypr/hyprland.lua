-- Omarchy Phone session entry point. Mirrors upstream's config/hypr/hyprland.lua
-- so a package update to the defaults still lands here, and adds only what the
-- phone needs: the device table and the one-window-per-workspace rule.

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Load Omarchy defaults. The phone overrides the handful of them that assume a
-- pointer or a keyboard; the rest it genuinely wants.
require("default.hypr.omarchy")

-- Phone overrides, loaded after the defaults so upstream can keep improving them.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Phone-only. Not in upstream's list, which is why this file exists rather than
-- the port relying on upstream's hyprland.lua being copied in.
require("hypr.windows")

-- Toggle config flags dynamically.
require("default.hypr.toggles")
