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
-- reading. On a phone a short press means "screen off"; long press belongs to
-- logind, which install/hardware/power-key.sh configures.
--
-- Screen off, and NOT locked -- for now. Omarchy's lock screen asks for a
-- typed password, and the phone's on-screen keyboard is a layer surface that a
-- session lock covers like every other, so a locked phone with no hardware
-- keyboard cannot be unlocked at all. Until a phone lock with its own PIN pad
-- exists (NOTES.md), locking would brick the session.
--
-- Off only from on, and a beat after the press. Hyprland runs a key's binds
-- first and then, for the same event, wakes the panel if it is off
-- (misc:key_press_enables_dpms, hypr/input.lua). Turning off inside the bind
-- would be undone by that wake on the spot, and toggling would turn a woken
-- panel straight back off; so a press on a dark panel is left to the wake,
-- and a press on a lit one blanks it once the key events are through.
hl.unbind("XF86PowerOff")
hl.bind("XF86PowerOff", function()
  local monitor = hl.get_active_monitor()
  if not monitor or not monitor.dpms_status then
    return
  end
  hl.timer(function()
    hl.dispatch(hl.dsp.dpms({ action = "off" }))
  end, { timeout = 400, type = "oneshot" })
end, { description = "Screen off" })
