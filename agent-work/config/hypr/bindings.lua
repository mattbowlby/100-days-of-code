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
-- Screen off, and NOT locked -- for now. The phone's lock screen (phone-lock)
-- unlocks by touch, with a passcode pad, but has not yet been seen working on
-- a phone, and a lock that cannot be unlocked can be left only by forcing the
-- phone off (NOTES.md). The control centre's Lock tile is the one way to lock
-- until it has.
--
-- Off only from on, and only once the button is let go. Hyprland runs a key's
-- binds first and then, for the same event -- press and release alike -- wakes
-- the panel if it is off (misc:key_press_enables_dpms, hypr/input.lua).
-- Turning off inside the bind would be undone by that wake on the spot, a
-- fixed delay would be undone by the release of a slow press, and toggling
-- would turn a woken panel straight back off. So a press on a dark panel is
-- left to the wake, and a press on a lit one blanks it after the release.
local function screen_off_after_release()
  hl.timer(function()
    if hl.is_key_down("XF86PowerOff") then
      return screen_off_after_release()
    end
    hl.dispatch(hl.dsp.dpms({ action = "off" }))
  end, { timeout = 50, type = "oneshot" })
end

hl.unbind("XF86PowerOff")
hl.bind("XF86PowerOff", function()
  local monitor = hl.get_active_monitor()
  if not monitor or not monitor.dpms_status then
    return
  end
  screen_off_after_release()
end, { description = "Screen off" })
