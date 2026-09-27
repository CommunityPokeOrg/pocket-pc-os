-- PocketOS Settings app: wallpaper, clock format, sound, storage reset.
local M = {}
local T, g, fs, shell

local function rows(self)
  local u = fs.usage()
  local storage
  if fs.isPersistent() then
    storage = string.format("Storage: %d/%d bytes", u.used, u.capacity)
  else
    storage = string.format("Storage: RAM only (~%db)", u.used)
  end
  return {
    { label = "Wallpaper: " .. T.wallpapers[shell.wallIdx].name, id = "wall" },
    { label = "Clock: " .. (shell.clockFmt24 and "24h" or "12h"), id = "clock" },
    { label = "Sound: " .. (self.sound and "on" or "off"), id = "sound" },
    { label = storage, id = nil },
    { label = self.confirm and "Tap again to WIPE!" or "Reset storage", id = "wipe" },
  }
end

function M.new(env)
  T, g, fs = env.theme, env.gfx, env.fs
  shell = env.shell
  local inst = { sound = true, confirm = false, speaker = env.hal.speaker }
  setmetatable(inst, { __index = M })
  return inst
end

function M:draw(ctx)
  local rs = rows(self)
  local rowH = T.fontH + 4
  for i = 1, #rs do
    local y = ctx.y + (i - 1) * rowH
    if rs[i].id then g.frame(ctx.x, y, ctx.w, rowH - 1, T.pal.shade) end
    g.textClip(ctx.x + 2, y + 2, rs[i].label, ctx.w - 4,
      rs[i].id == "wipe" and self.confirm and T.pal.warn or T.pal.black)
  end
end

function M:touchDown(x, y, ctx)
  local rowH = T.fontH + 4
  local row = math.floor(y / rowH) + 1
  local rs = rows(self)
  local r = rs[row]
  if not r or not r.id then return end
  if r.id == "wall" then
    shell.wallIdx = shell.wallIdx % #T.wallpapers + 1
    fs.setSetting("wallpaper", shell.wallIdx)
  elseif r.id == "clock" then
    shell.clockFmt24 = not shell.clockFmt24
    fs.setSetting("clock24", shell.clockFmt24)
  elseif r.id == "sound" then
    self.sound = not self.sound
    if self.speaker then self.speaker.State = self.sound end
  elseif r.id == "wipe" then
    if self.confirm then
      fs.reset()
      self.confirm = false
      shell.wallIdx = 1
      shell.clockFmt24 = true
    else
      self.confirm = true
    end
  end
end

return M
