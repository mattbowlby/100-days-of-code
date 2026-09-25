# A phone's power button: short press locks and blanks the panel (bound in
# config/hypr/bindings.lua), long press forces power off.
#
# Omarchy already sets HandlePowerKey=ignore so the compositor can own the short
# press, which leaves the long press unhandled. A phone has no keyboard, no lid
# and no reset pinhole, so it needs one way out that does not depend on a
# compositor still being alive to answer a keybinding.
power_key_file=/etc/systemd/logind.conf.d/20-omarchy-phone-power-key.conf

if [[ ! -f $power_key_file ]]; then
  sudo mkdir -p /etc/systemd/logind.conf.d
  sudo tee "$power_key_file" >/dev/null <<'CONF'
[Login]
HandlePowerKeyLongPress=poweroff
CONF
fi
