-- One window per workspace.
--
-- This is the port's layout model, and it is a consequence of the input layer
-- rather than a taste: dwindle's split would give two 180px columns on this
-- panel, which is not a usable phone window, and the alternative -- a scrolling
-- layout at full column width -- needs a one-finger gesture to move between
-- columns. hl.gesture() enforces fingers >= 2, so no such gesture exists, and a
-- window past the first would be unreachable by touch. Workspaces are reachable:
-- gestures:workspace_swipe_touch moves between them with one finger.
--
-- So each window gets its own workspace, and the horizontal swipe moves between
-- apps; swipe up and hold opens the app switcher. See NOTES.md.

-- A shape surprise would otherwise fire on every window open, so the complaint
-- is said once and then the rule just stays quiet.
local reported = false

hl.on("window.open", function(window)
  -- The payload shape is the one thing that could not be confirmed off-device:
  -- handlers registered through `hyprctl eval` do not persist, so window.open
  -- was never observed firing here. Everything below is therefore written so
  -- that a surprise degrades to "no separation" instead of moving a window the
  -- user is in the middle of using. Confirm on hardware and simplify.
  local ok, err = pcall(function()
    if type(window) ~= "userdata" then
      return
    end

    -- Floating windows are dialogs, pickers and menus. They belong on top of
    -- whatever opened them, not exiled to a screen of their own.
    if window.floating then
      return
    end

    local workspace = window.workspace
    if not workspace then
      return
    end

    -- Special workspaces (the scratchpad) are a deliberate stack. Hyprland
    -- numbers them negatively.
    if (workspace.id or 0) < 0 then
      return
    end

    -- Nothing to separate this window from.
    if (workspace.windows or 0) <= 1 then
      return
    end

    -- hl.dsp.window.move takes no window argument -- its accepted arguments are
    -- direction, x+y(+relative), workspace, into_group and out_of_group -- so it
    -- acts on whatever currently holds focus. Only move when the window that
    -- just opened is that window, or a background window opening would exile the
    -- foreground one.
    local active = hl.get_active_window()
    if not active or active.address ~= window.address then
      return
    end

    hl.dispatch(hl.dsp.window.move({ workspace = "empty" }))
  end)

  if not ok and not reported then
    -- Never let a layout nicety take the compositor's window-open path with it.
    reported = true
    hl.exec_cmd(o.notify("omarchy-phone: window placement failed: " .. tostring(err)))
  end
end)
