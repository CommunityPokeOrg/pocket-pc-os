-- PocketOS fs: flat-path virtual filesystem backed by FlashMemory when the
-- gadget has a flash chip, otherwise RAM-only. Also stores OS settings so all
-- persistent state round-trips through one Save/Load.
local M = {}

local flash
local vol -- { files = {path->string}, settings = {k->v} }

local function seed()
  vol = { files = {}, settings = {} }
  vol.files["/readme.txt"] =
    "Welcome to PocketOS!\n" ..
    "Tap icons to open apps.\n" ..
    "Try the terminal: type 'help'."
  vol.files["/todo.txt"] = "1. Explore\n2. Paint something\n3. Save it"
end

function M.init(hal)
  flash = hal.flash
end

function M.load()
  vol = nil
  if flash then
    local ok, t = pcall(function() return flash:Load() end)
    if ok and type(t) == "table" and type(t.files) == "table" then
      vol = t
    end
  end
  if type(vol) ~= "table" then seed() end
  if type(vol.settings) ~= "table" then vol.settings = {} end
end

-- Persist the whole volume. Silent no-op without flash or on capacity errors.
function M.flush()
  if flash then
    pcall(function() flash:Save(vol) end)
  end
end

function M.read(path)
  return vol.files[path]
end

function M.write(path, data)
  vol.files[path] = tostring(data)
  M.flush()
  return true
end

function M.delete(path)
  if vol.files[path] == nil then return false end
  vol.files[path] = nil
  M.flush()
  return true
end

function M.exists(path)
  return vol.files[path] ~= nil
end

-- Sorted array of { path=..., size=... }.
function M.list()
  local out = {}
  for p, data in pairs(vol.files) do
    out[#out + 1] = { path = p, size = #data }
  end
  table.sort(out, function(a, b) return a.path < b.path end)
  return out
end

function M.getSetting(key, default)
  local v = vol.settings[key]
  if v == nil then return default end
  return v
end

function M.setSetting(key, value)
  vol.settings[key] = value
  M.flush()
end

function M.reset()
  seed()
  M.flush()
end

-- Flash usage stats, or an estimate of serialized size without a chip.
function M.usage()
  if flash then
    return { used = flash.Usage, capacity = flash.Size }
  end
  local n = 0
  for _, d in pairs(vol.files) do n = n + #d end
  return { used = n, capacity = 0 }
end

function M.isPersistent()
  return flash ~= nil
end

return M
