-- PocketOS Paint app: 1-bit-per-pixel palette canvas drawn with the stylus.
-- Canvas rows serialize to strings so files round-trip through FlashMemory.
local M = {}
local T, g, fs

local PAL_KEYS = "12345678"

function M.new(env)
  T, g, fs = env.theme, env.gfx, env.fs
  local inst = { sel = 2, saveN = 0, msg = "" }
  setmetatable(inst, { __index = M })
  return inst
end

local function palH() return 12 end

local function canvasSize(ctx)
  return math.max(1, ctx.w), math.max(1, ctx.h - palH())
end

local function ensureCanvas(self, ctx)
  local w, h = canvasSize(ctx)
  if self.grid and self.gw == w and self.gh == h then return end
  local grid = {}
  for y = 1, h do
    local row = {}
    for x = 1, w do row[x] = 0 end
    grid[y] = row
  end
  -- keep overlapping pixels when the canvas resizes
  if self.grid then
    for y = 1, math.min(h, self.gh) do
      for x = 1, math.min(w, self.gw) do
        grid[y][x] = self.grid[y][x]
      end
    end
  end
  self.grid, self.gw, self.gh = grid, w, h
end

local function plot(self, x, y, ctx)
  ensureCanvas(self, ctx)
  local px, py = math.floor(x), math.floor(y - palH())
  if px >= 0 and py >= 1 and px < self.gw and py <= self.gh then
    self.grid[py][px + 1] = self.sel
  end
end

function M:draw(ctx)
  ensureCanvas(self, ctx)
  -- palette strip
  for i = 1, 8 do
    local bx = ctx.x + (i - 1) * 8
    g.rect(bx, ctx.y, 7, 8, T.paintPal[i])
    if i == self.sel then g.frame(bx - 1, ctx.y - 1, 9, 10, T.pal.black) end
  end
  g.button(ctx.x + ctx.w - 36, ctx.y, 17, 10, "CLR")
  g.button(ctx.x + ctx.w - 17, ctx.y, 17, 10, "SAV")
  if self.msg ~= "" then
    g.textClip(ctx.x + 68, ctx.y + 1, self.msg, ctx.w - 106, T.pal.dark)
  end
  -- canvas
  local cy = ctx.y + palH()
  g.rect(ctx.x, cy, self.gw, self.gh, T.pal.white)
  for y = 1, self.gh do
    local row = self.grid[y]
    for x = 1, self.gw do
      local v = row[x]
      if v and v > 0 then
        g.rect(ctx.x + x - 1, cy + y - 1, 1, 1, T.paintPal[v])
      end
    end
  end
  g.frame(ctx.x, cy, self.gw, self.gh, T.pal.shade)
end

function M:touchDown(x, y, ctx)
  if y < palH() then
    local pi = math.floor(x / 8) + 1
    if pi >= 1 and pi <= 8 then self.sel = pi; return end
    if x >= ctx.w - 36 and x < ctx.w - 17 then -- CLR
      self.grid = nil
      ensureCanvas(self, ctx)
      self.msg = ""
      return
    end
    if x >= ctx.w - 17 then -- SAV
      self.saveN = self.saveN + 1
      local path = "/paint_" .. self.saveN .. ".img"
      local rows = {}
      for ry = 1, self.gh do
        local chars = {}
        for rx = 1, self.gw do
          chars[rx] = tostring(self.grid[ry][rx] or 0)
        end
        rows[ry] = table.concat(chars)
      end
      fs.write(path, table.concat(rows, "\n"))
      self.msg = "saved " .. path
      return
    end
    return
  end
  plot(self, x, y, ctx)
end

function M:touchMove(x, y, ctx)
  plot(self, x, y, ctx)
end

function M:key(name, char, down)
  if not down or not char then return end
  local i = PAL_KEYS:find(char, 1, true)
  if i then self.sel = i end
end

return M
