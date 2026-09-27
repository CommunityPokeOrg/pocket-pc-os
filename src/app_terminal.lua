-- PocketOS Terminal app: a tiny command shell over the virtual fs.
local M = {}
local T, g, fs, hal

function M.new(env)
  T, g, fs, hal = env.theme, env.gfx, env.fs, env.hal
  local inst = {
    wm = env.wm,
    lines = { "PocketOS terminal", "type 'help' for commands" },
    input = "",
    scroll = 0,
  }
  setmetatable(inst, { __index = M })
  return inst
end

local function push(self, s)
  self.lines[#self.lines + 1] = s
  if #self.lines > 200 then table.remove(self.lines, 1) end
  self.scroll = 0
end

local function words(s)
  local out = {}
  for w in s:gmatch("%S+") do out[#out + 1] = w end
  return out
end

local function normPath(p)
  if not p or p == "" then return nil end
  if p:sub(1, 1) ~= "/" then p = "/" .. p end
  return p
end

local function exec(self, line)
  push(self, "> " .. line)
  local w = words(line)
  local cmd = w[1]
  if not cmd then return end
  if cmd == "help" then
    push(self, "help echo ls cat write rm touch date uptime ver clear exit")
  elseif cmd == "echo" then
    push(self, table.concat(w, " ", 2))
  elseif cmd == "ls" then
    for _, f in ipairs(fs.list()) do
      push(self, string.format("%-16s %4d", f.path, f.size))
    end
  elseif cmd == "cat" then
    local p = normPath(w[2])
    local d = p and fs.read(p)
    if d then
      for l in (d .. "\n"):gmatch("([^\n]*)\n") do push(self, l) end
    else
      push(self, "no such file: " .. tostring(w[2]))
    end
  elseif cmd == "write" then
    local p = normPath(w[2])
    if not p then push(self, "usage: write <file> <text>") return end
    fs.write(p, table.concat(w, " ", 3))
    push(self, "wrote " .. p)
  elseif cmd == "touch" then
    local p = normPath(w[2])
    if p and not fs.exists(p) then fs.write(p, "") end
    push(self, p and ("ok " .. p) or "usage: touch <file>")
  elseif cmd == "rm" then
    local p = normPath(w[2])
    push(self, (p and fs.delete(p)) and ("deleted " .. p) or "no such file")
  elseif cmd == "date" then
    local d = hal.datetime()
    if d then
      push(self, string.format("%04d-%02d-%02d %02d:%02d:%02d",
        d.year, d.month, d.day, d.hour, d.min, d.sec))
    else
      push(self, "no RTC (add a RealityChip)")
    end
  elseif cmd == "uptime" then
    push(self, string.format("%.1fs", hal.time()))
  elseif cmd == "ver" then
    push(self, "PocketOS 0.1 on Retro Gadgets " .. hal.W .. "x" .. hal.H)
  elseif cmd == "clear" then
    self.lines = {}
  elseif cmd == "exit" then
    self.wm:closeInst(self)
  else
    push(self, "unknown: " .. cmd)
  end
end

function M:key(name, char, down)
  if not down then return end
  if char and char ~= "\t" then
    self.input = self.input .. char
  elseif name == "Backspace" then
    self.input = self.input:sub(1, -2)
  elseif name == "Return" then
    exec(self, self.input)
    self.input = ""
  end
end

function M:draw(ctx)
  g.rect(ctx.x, ctx.y, ctx.w, ctx.h, T.pal.termBg)
  local lineH = T.fontH + 1
  local maxLines = math.floor(ctx.h / lineH)
  local start = math.max(1, #self.lines - maxLines + 1 - self.scroll)
  local y = ctx.y
  for i = start, #self.lines do
    g.textClip(ctx.x + 1, y, self.lines[i], ctx.w - 2, T.pal.termFg)
    y = y + lineH
    if y > ctx.y + ctx.h - lineH then break end
  end
  -- prompt with blinking cursor
  local prompt = "> " .. self.input
  if hal.time() % 1 < 0.5 then prompt = prompt .. "_" end
  g.textClip(ctx.x + 1, ctx.y + ctx.h - lineH, prompt, ctx.w - 2, T.pal.termFg)
end

return M
