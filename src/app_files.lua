-- PocketOS Files app: browse the virtual fs, preview a file, create/delete.
local M = {}
local T, g, fs

function M.new(env)
  T, g, fs = env.theme, env.gfx, env.fs
  local inst = { sel = 1, newN = 0 }
  setmetatable(inst, { __index = M })
  return inst
end

local function entries(self)
  self.list = fs.list()
  if self.sel > #self.list then self.sel = #self.list end
  if self.sel < 1 then self.sel = 1 end
  return self.list
end

function M:draw(ctx)
  local list = entries(self)
  local rowH = T.fontH + 2
  local listH = ctx.h - 14
  local y = ctx.y
  for i = 1, #list do
    local f = list[i]
    if i == self.sel then
      g.rect(ctx.x, y, ctx.w, rowH, T.pal.selBg)
    end
    g.textClip(ctx.x + 2, y + 1, f.path, ctx.w - 34,
      i == self.sel and T.pal.white or T.pal.black)
    g.textClip(ctx.x + ctx.w - 30, y + 1, tostring(f.size) .. "b", 30,
      i == self.sel and T.pal.white or T.pal.dark)
    y = y + rowH
    if y > ctx.y + listH - rowH then break end
  end
  if #list == 0 then
    g.textClip(ctx.x + 2, y + 1, "(empty)", ctx.w - 4, T.pal.dark)
  end
  -- selected file preview strip + buttons row
  local sel = list[self.sel]
  local by = ctx.y + ctx.h - 12
  g.button(ctx.x, by, 18, 11, "New")
  g.button(ctx.x + 20, by, 18, 11, "Del")
  if sel then
    local d = fs.read(sel.path) or ""
    g.textClip(ctx.x + 42, by + 1, d:gsub("\n", " "), ctx.w - 44, T.pal.dark)
  end
end

local function btnRow(self, ctx)
  local by = ctx.y + ctx.h - 12
  return { { x = ctx.x, y = by, w = 18, h = 11, id = "new" },
           { x = ctx.x + 20, y = by, w = 18, h = 11, id = "del" } }
end

function M:touchDown(x, y, ctx)
  for _, b in ipairs(btnRow(self, ctx)) do
    if g.hit(x, y, b.x - ctx.x, b.y - ctx.y, b.w, b.h) then
      if b.id == "new" then
        self.newN = self.newN + 1
        fs.write("/new_" .. self.newN .. ".txt", "")
      else
        local sel = self.list and self.list[self.sel]
        if sel then fs.delete(sel.path) end
      end
      return
    end
  end
  local rowH = T.fontH + 2
  local row = math.floor(y / rowH) + 1
  local list = entries(self)
  if row >= 1 and row <= #list then self.sel = row end
end

return M
