-- Touch-first bindings.
--
-- The desktop's SUPER bindings are deliberately left in place. With no built-in
-- keyboard they are inert, and every one of them comes back for free the moment
-- a Bluetooth keyboard is paired -- unbinding ~100 working bindings to tidy away
-- a keyboard the device might yet have would be a loss, not a cleanup. Only the
-- bindings whose meaning genuinely differs on a phone are overridden here.
--
-- The lid-switch bindings in default/hypr/bindings/utilities.lua are left alone
-- for the same reason: a phone has no lid, so they never fire.

-- Omarchy ships HandlePowerKey=ignore in logind so the compositor owns the
-- power button, and upstream spends it on the system menu. That is a desktop
-- reading. On a phone a short press means "screen off, locked", and
-- omarchy-system-lock is already exactly that -- its own summary is "Lock the
-- computer and turn off the display". Long press belongs to logind, which
-- install/hardware/power-key.sh configures.
--
-- Deliberately not `locked = true`: while the session is locked, the power
-- button's job is to wake the panel, which misc:key_press_enables_dpms in
-- hypr/input.lua does. Re-firing the lock on top of the wake would fight it.
hl.unbind("XF86PowerOff")
o.bind("XF86PowerOff", "Lock and blank", "omarchy-system-lock")
