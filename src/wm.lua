-- PocketOS window manager: overlapping draggable windows with a title bar,
-- close box, and focus/z-ordering. wins[#wins] is the topmost (drawn last).
local WM = {}
WM.__index = WM

function WM.new(env) -- env: {hal, theme, gfx}
  return setmetatable({
    env = env,
    wins = {},
    cascade = 0,
    drag = nil,   -- {win=, dx=, dy=}
    pressed = nil, -- win that received the current touch-down
  }, WM)
end

function WM:open(title, inst, w, h)
  local T, hal = self.env.theme, self.env.hal
  local sw, sh = hal.W, hal.H
  w = math.min(w or math.floor(sw * 0.7), sw - 4)
  h = math.min(h or math.floor(sh * 0.7), sh - T.taskbarH - 4)
  local win = {
    title = title,
    inst = inst,
    w = w,
    h = h,
    x = 2 + (self.cascade % 4) * 6,
    y = 2 + (self.cascade % 4) * 5,
  }
  self.cascade = self.cascade + 1
  self.wins[#self.wins + 1] = win
  self:focus(win)
  if inst.onOpen then inst:onOpen(self:content(win)) end
  return win
end

function WM:close(win)
  for i = #self.wins, 1, -1 do
    if self.wins[i] == win then
      if win.inst.onClose then win.inst:onClose() end
      table.remove(self.wins, i)
      if self.drag and self.drag.win == win then self.drag = nil end
      if self.pressed == win then self.pressed = nil end
      return true
    end
  end
  return false
end

function WM:closeInst(inst)
  for i = #self.wins, 1, -1 do
    if self.wins[i].inst == inst then return self:close(self.wins[i]) end
  end
  return false
end

function WM:focus(win)
  for i = #self.wins, 1, -1 do
    if self.wins[i] == win then
      table.remove(self.wins, i)
      self.wins[#self.wins + 1] = win
      return
    end
  end
end

function WM:focused()
  return self.wins[#self.wins]
end

function WM:count()
  return #self.wins
end

function WM:content(win)
  local T = self.env.theme
  return {
    x = win.x + T.border,
    y = win.y + T.titleH,
    w = win.w - 2 * T.border,
    h = win.h - T.titleH - T.border,
  }
end

local function closeRect(win, T)
  return win.x + win.w - T.titleH - 1, win.y + 1, T.titleH - 1, T.titleH - 2
end

-- Topmost window whose frame (title+body+border) contains the point.
function WM:winAt(x, y)
  for i = #self.wins, 1, -1 do
    local w = self.wins[i]
    if x >= w.x and y >= w.y and x < w.x + w.w and y < w.y + w.h then
      return w
    end
  end
  return nil
end

-- Returns true if the WM consumed the touch (title/close); on body touches it
-- forwards to the app and also returns true.
function WM:touchDown(x, y)
  local T = self.env.theme
  local win = self:winAt(x, y)
  if not win then return false end
  self:focus(win)
  self.pressed = win
  local cx, cy, cw, ch = closeRect(win, T)
  if self.env.gfx.hit(x, y, cx, cy, cw, ch) then
    self:close(win)
    return true
  end
  if y < win.y + T.titleH then
    self.drag = { win = win, dx = x - win.x, dy = y - win.y }
    return true
  end
  if win.inst.touchDown then
    local c = self:content(win)
    win.inst:touchDown(x - c.x, y - c.y, c)
  end
  return true
end

function WM:touchMove(x, y)
  if self.drag then
    local hal, T = self.env.hal, self.env.theme
    local win = self.drag.win
    win.x = math.max(-win.w + 12, math.min(hal.W - 12, x - self.drag.dx))
    win.y = math.max(0, math.min(hal.H - T.taskbarH - 6, y - self.drag.dy))
    return true
  end
  local win = self.pressed
  if win and win.inst.touchMove then
    local c = self:content(win)
    win.inst:touchMove(x - c.x, y - c.y, c)
  end
  return win ~= nil
end

function WM:touchUp(x, y)
  self.drag = nil
  local win = self.pressed
  self.pressed = nil
  if win and win.inst.touchUp then
    local c = self:content(win)
    win.inst:touchUp(x - c.x, y - c.y, c)
  end
end

function WM:key(name, char, down)
  local win = self:focused()
  if win and win.inst.key then
    win.inst:key(name, char, down)
    return true
  end
  return false
end

function WM:draw()
  local g, T = self.env.gfx, self.env.theme
  local focused = self:focused()
  for i = 1, #self.wins do
    local win = self.wins[i]
    local on = win == focused
    -- drop shadow
    g.rect(win.x + 1, win.y + win.h, win.w, 1, T.pal.dark)
    g.rect(win.x + win.w, win.y + 1, 1, win.h, T.pal.dark)
    -- face + border
    g.rect(win.x, win.y, win.w, win.h, T.pal.face)
    g.bevel(win.x, win.y, win.w, win.h, true)
    -- title bar
    g.rect(win.x + 1, win.y + 1, win.w - 2, T.titleH - 1,
      on and T.pal.titleOn or T.pal.titleOff)
    g.textClip(win.x + 3, win.y + 1, win.title, win.w - T.titleH - 6,
      T.pal.white)
    -- close box
    local cx, cy, cw, ch = closeRect(win, T)
    g.button(cx, cy, cw, ch, "x", false)
    -- app body
    if win.inst.draw then
      win.inst:draw(self:content(win))
    end
  end
end

return WM
