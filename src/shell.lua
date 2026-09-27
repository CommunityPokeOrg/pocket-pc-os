-- PocketOS shell: desktop icons, taskbar (Start button, window buttons,
-- clock), and Start menu. Routes all input to the WM or to itself.
local Shell = {}
Shell.__index = Shell

-- Stylus cursor dot; pcall-guarded since TouchPosition can sit off-bounds.
local function safePixel(v, x, y, c)
  pcall(function() v:SetPixel(vec2(math.floor(x), math.floor(y)), c) end)
end

function Shell.new(env) -- env: {hal, theme, gfx, wm, fs, apps}
  return setmetatable({
    env = env,
    menuOpen = false,
    pressT = 0,
    clockStr = "--:--",
    clockFmt24 = env.fs.getSetting("clock24", true),
    wallIdx = env.fs.getSetting("wallpaper", 1),
  }, Shell)
end

function Shell:launch(id)
  local env = self.env
  local app = env.apps.get(id)
  if not app then return end
  local inst = app.open(env)
  env.wm:open(app.title, inst, app.w, app.h)
  self.menuOpen = false
end

local function iconRect(self, i)
  local T = self.env.theme
  local col = math.floor((i - 1) / math.max(1, math.floor((self.env.hal.H - T.taskbarH) / T.iconH)))
  local row = (i - 1) % math.max(1, math.floor((self.env.hal.H - T.taskbarH) / T.iconH))
  return 2 + col * (T.iconW + 4), 2 + row * (T.iconH + 4), T.iconW, T.iconH
end

function Shell:iconAt(x, y)
  local apps = self.env.apps.list
  for i = 1, #apps do
    local ix, iy, iw, ih = iconRect(self, i)
    if self.env.gfx.hit(x, y, ix, iy, iw, ih) then return apps[i] end
  end
  return nil
end

function Shell:taskbarTop()
  return self.env.hal.H - self.env.theme.taskbarH
end

local function menuRect(self)
  local T = self.env.theme
  local items = self.env.apps.list
  local w = 56
  local h = #items * T.menuRowH + 4
  return 1, self:taskbarTop() - h, w, h
end

local function startRect(self)
  return 1, self:taskbarTop() + 1, 24, self.env.theme.taskbarH - 2
end

function Shell:update()
  local d = self.env.hal.datetime()
  if d then
    local h = d.hour
    if not self.clockFmt24 then
      h = h % 12
      if h == 0 then h = 12 end
    end
    self.clockStr = string.format("%02d:%02d", h, d.min)
  else
    local t = math.floor(self.env.hal.time())
    self.clockStr = string.format("%02d:%02d", math.floor(t / 60) % 24, t % 60)
  end
end

-- Input ---------------------------------------------------------------------

function Shell:touchDown(x, y)
  local env = self.env
  -- taskbar
  if y >= self:taskbarTop() then
    local sx, sy, sw, sh = startRect(self)
    if env.gfx.hit(x, y, sx, sy, sw, sh) then
      self.menuOpen = not self.menuOpen
      return true
    end
    -- window buttons
    local bx = sx + sw + 2
    local bw = 28
    for _, win in ipairs(env.wm.wins) do
      if env.gfx.hit(x, y, bx, sy, bw, sh) then
        env.wm:focus(win)
        return true
      end
      bx = bx + bw + 1
    end
    return true
  end
  -- start menu
  if self.menuOpen then
    local mx, my, mw, mh = menuRect(self)
    if env.gfx.hit(x, y, mx, my, mw, mh) then
      local row = math.floor((y - my - 2) / env.theme.menuRowH) + 1
      local app = env.apps.list[row]
      if app then self:launch(app.id) end
    else
      self.menuOpen = false
    end
    return true
  end
  -- windows
  if env.wm:touchDown(x, y) then return true end
  -- desktop icons
  local app = self:iconAt(x, y)
  if app then
    self:launch(app.id)
    return true
  end
  return false
end

function Shell:touchMove(x, y)
  self.env.wm:touchMove(x, y)
end

function Shell:touchUp(x, y)
  self.env.wm:touchUp(x, y)
end

function Shell:key(name, char, down)
  if down and name == "Escape" then
    if self.menuOpen then self.menuOpen = false; return true end
    local win = self.env.wm:focused()
    if win then self.env.wm:close(win); return true end
  end
  return self.env.wm:key(name, char, down)
end

-- Drawing -------------------------------------------------------------------

function Shell:draw()
  local env = self.env
  local g, T, hal = env.gfx, env.theme, env.hal
  -- wallpaper
  g.rect(0, 0, hal.W, hal.H, T.wallpapers[self.wallIdx].c)
  -- desktop icons
  for i = 1, #env.apps.list do
    local app = env.apps.list[i]
    local ix, iy, iw, ih = iconRect(self, i)
    g.rect(ix + 6, iy + 1, 16, 12, T.pal.face)
    g.bevel(ix + 6, iy + 1, 16, 12, true)
    g.textClip(ix + 8, iy + 3, app.glyph, 12, T.pal.black)
    g.textClip(ix, iy + 15, app.title, iw, T.pal.white)
  end
  -- windows
  env.wm:draw()
  -- taskbar
  local ty = self:taskbarTop()
  g.rect(0, ty, hal.W, T.taskbarH, T.pal.face)
  g.bevel(0, ty, hal.W, T.taskbarH, true)
  local sx, sy, sw, sh = startRect(self)
  g.button(sx, sy, sw, sh, "Start", self.menuOpen)
  local bx = sx + sw + 2
  local focused = env.wm:focused()
  for _, win in ipairs(env.wm.wins) do
    g.button(bx, sy, 28, sh, win.title, win == focused)
    bx = bx + 29
  end
  -- clock
  g.textClip(hal.W - 26, ty + 2, self.clockStr, 26, T.pal.black)
  -- start menu (topmost overlay)
  if self.menuOpen then
    local mx, my, mw, mh = menuRect(self)
    g.rect(mx, my, mw, mh, T.pal.face)
    g.bevel(mx, my, mw, mh, true)
    for i = 1, #env.apps.list do
      local app = env.apps.list[i]
      local ry = my + 2 + (i - 1) * T.menuRowH
      g.textClip(mx + 4, ry + 1, app.title, mw - 8, T.pal.black)
    end
  end
  -- touch cursor dot while stylus is down
  local v = hal.video
  if v.TouchState then
    local p = v.TouchPosition
    safePixel(v, p.X, p.Y, T.pal.white)
  end
end

return Shell
