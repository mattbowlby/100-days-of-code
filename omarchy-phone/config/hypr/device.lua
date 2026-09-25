-- The device profile for the phone this session is running on.
--
-- Modules that need panel geometry or peripheral flags require this table
-- rather than shelling out per lookup. Mirrors default/hypr/paths.lua: a plain
-- table of resolved values, read once at config load.

local phone_path = os.getenv("OMARCHY_PHONE_PATH") or "/usr/share/omarchy-phone"

local function read_profile()
  local values = {}

  -- One detection path for the whole port: omarchy-phone-device owns device
  -- tree matching and the installer override, and this reads back whatever it
  -- resolved. Runs once per config load, so the popen costs nothing at runtime.
  local pipe = io.popen(phone_path .. "/bin/omarchy-phone-device --profile 2>/dev/null")
  if not pipe then
    return values
  end

  -- Same KEY=value parse as the /etc/vconsole.conf reader in
  -- default/hypr/input.lua; the profile format exists to need no more than this.
  for line in pipe:lines() do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key and value then
      value = value:gsub("%s+#.*$", "")
      value = value:gsub('^"(.*)"$', "%1")
      values[key] = value
    end
  end

  pipe:close()
  return values
end

local profile = read_profile()

local function number(key, fallback)
  return tonumber(profile[key]) or fallback
end

local function has(key)
  return profile[key] == "1"
end

local scale = number("DEVICE_SCALE", 2)
local transform = number("DEVICE_TRANSFORM", 0)

-- Logical panel size: what the compositor lays out in, not what the panel
-- holds. Gesture distances and any size a finger has to cross belong in these
-- units -- a desktop-shaped pixel count is meaningless at scale 3.
local function logical_size()
  local width, height = tostring(profile.DEVICE_MODE or ""):match("^(%d+)x(%d+)")
  if not width or scale <= 0 then
    return nil, nil
  end

  width = math.floor(tonumber(width) / scale + 0.5)
  height = math.floor(tonumber(height) / scale + 0.5)

  -- transform 1 and 3 are the quarter turns, and they swap the axes. Reporting
  -- the unrotated size on a rotated panel would put every derived threshold on
  -- the wrong axis.
  if transform == 1 or transform == 3 then
    return height, width
  end
  return width, height
end

local logical_width, logical_height = logical_size()

-- Fallbacks are the desktop's defaults on purpose: an unrecognised machine
-- (running the phone session on a dev box) then gets Omarchy's ordinary
-- autodetected monitor instead of a DSI panel that isn't there.
return {
  codename = profile.DEVICE_CODENAME or "unknown",
  name = profile.DEVICE_NAME or "Unknown device",
  output = profile.DEVICE_OUTPUT or "",
  mode = profile.DEVICE_MODE or "preferred",
  scale = scale,
  transform = transform,
  logical_width = logical_width,
  logical_height = logical_height,
  has_modem = has("DEVICE_HAS_MODEM"),
  has_battery = has("DEVICE_HAS_BATTERY"),
  has_torch = has("DEVICE_HAS_TORCH"),
  has_keyboard = has("DEVICE_HAS_KEYBOARD"),
}
