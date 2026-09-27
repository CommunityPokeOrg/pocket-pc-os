-- Retro Gadgets gdt/API stub for headless testing under LuaJIT (Lua 5.1).
-- Mimics the documented API surface PocketOS uses: VideoChip (with a real
-- framebuffer), KeyboardChip events, CPU time, ROM StandardFont, FlashMemory,
-- RealityChip and Speaker.
local M = {}

function M.install(w, h)
  w, h = w or 128, h or 72

  local function vec2mt()
    return {
      __add = function(a, b) return vec2(a.X + b.X, a.Y + b.Y) end,
      __sub = function(a, b) return vec2(a.X - b.X, a.Y - b.Y) end,
      __mul = function(a, b)
        if type(a) == "number" then return vec2(a * b.X, a * b.Y) end
        if type(b) == "number" then return vec2(a.X * b, a.Y * b) end
        return vec2(a.X * b.X, a.Y * b.Y)
      end,
      __tostring = function(v) return "vec2(" .. v.X .. "," .. v.Y .. ")" end,
    }
  end
  function vec2(x, y)
    return setmetatable({ X = x or 0, Y = y or 0 }, vec2mt())
  end
  function vec3(x, y, z)
    return { X = x or 0, Y = y or 0, Z = z or 0 }
  end

  function Color(r, g, b) return { r = r, g = g, b = b, a = 255 } end
  function ColorRGBA(r, g, b, a) return { r = r, g = g, b = b, a = a } end
  function ColorHSV(hh, s, v) return { h = hh, s = s, v = v } end
  color = {
    black = Color(0, 0, 0), white = Color(255, 255, 255),
    red = Color(255, 0, 0), green = Color(0, 255, 0),
    blue = Color(0, 0, 255), yellow = Color(255, 255, 0),
    cyan = Color(0, 255, 255), magenta = Color(255, 0, 255),
    gray = Color(128, 128, 128), clear = ColorRGBA(0, 0, 0, 0),
  }

  local logs = {}
  function log(s) logs[#logs + 1] = tostring(s) end

  local video = {
    Width = w,
    Height = h,
    TouchState = false,
    TouchDown = false,
    TouchUp = false,
    TouchPosition = vec2(0, 0),
    texts = {},   -- recorded DrawText calls: {x,y,s}
    ops = 0,
    fb = {},
  }
  for y = 1, h do
    local row = {}
    for x = 1, w do row[x] = nil end
    video.fb[y] = row
  end

  local function clampSet(vid, x, y, c)
    x, y = math.floor(x), math.floor(y)
    if x >= 0 and y >= 0 and x < vid.Width and y < vid.Height then
      vid.fb[y + 1][x + 1] = c
    end
  end

  function video:Clear(c)
    for y = 1, self.Height do
      for x = 1, self.Width do self.fb[y][x] = c end
    end
    self.ops = self.ops + 1
  end
  function video:SetPixel(p, c) clampSet(self, p.X, p.Y, c); self.ops = self.ops + 1 end
  function video:FillRect(p1, p2, c)
    local x1, x2 = math.min(p1.X, p2.X), math.max(p1.X, p2.X)
    local y1, y2 = math.min(p1.Y, p2.Y), math.max(p1.Y, p2.Y)
    for y = y1, y2 do for x = x1, x2 do clampSet(self, x, y, c) end end
    self.ops = self.ops + 1
  end
  function video:DrawRect(p1, p2, c)
    self:FillRect(p1, vec2(p2.X, p1.Y), c)
    self:FillRect(vec2(p1.X, p2.Y), p2, c)
    self:FillRect(vec2(p1.X, p1.Y), vec2(p1.X, p2.Y), c)
    self:FillRect(vec2(p2.X, p1.Y), p2, c)
  end
  function video:DrawLine(a, b, c)
    local x0, y0, x1, y1 = math.floor(a.X), math.floor(a.Y),
      math.floor(b.X), math.floor(b.Y)
    local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
      clampSet(self, x0, y0, c)
      if x0 == x1 and y0 == y1 then break end
      local e2 = 2 * err
      if e2 >= dy then err = err + dy; x0 = x0 + sx end
      if e2 <= dx then err = err + dx; y0 = y0 + sy end
    end
    self.ops = self.ops + 1
  end
  function video:DrawText(p, font, s, fg, bg)
    self.texts[#self.texts + 1] = { x = p.X, y = p.Y, s = s, fg = fg }
    -- fake 5x8 glyphs so pixel assertions can see text ink
    for i = 1, #s do
      local cx = p.X + (i - 1) * 5
      clampSet(self, cx, p.Y, fg)
      clampSet(self, cx, p.Y + 7, fg)
    end
    self.ops = self.ops + 1
  end
  function video:DrawCircle() self.ops = self.ops + 1 end
  function video:FillCircle() self.ops = self.ops + 1 end
  function video:RenderOnScreen() end
  function video:BlitPixelData() self.ops = self.ops + 1 end
  function video:pixelAt(x, y)
    return self.fb[y + 1] and self.fb[y + 1][x + 1]
  end
  function video:lastText()
    return self.texts[#self.texts] and self.texts[#self.texts].s
  end
  function video:findText(needle)
    for _, t in ipairs(self.texts) do
      if t.s and t.s:find(needle, 1, true) then return t end
    end
    return nil
  end

  local cpu = { Time = 0, DeltaTime = 1 / 60, EventChannels = {} }
  local saved = nil
  local flash = {
    Size = 32768,
    Usage = 0,
    Save = function(self, t) saved = t; self.Usage = 256; return true end,
    Load = function() return saved end,
  }
  local rtc = {
    GetDateTime = function()
      return { year = 2026, month = 9, day = 27, yday = 270, wday = 1,
               hour = 8, min = 3, sec = 0, isdst = false }
    end,
  }

  gdt = {
    VideoChip0 = video,
    CPU0 = cpu,
    KeyboardChip0 = {},
    ROM = { System = { SpriteSheets = { StandardFont = {} } },
            User = { SpriteSheets = {}, Codes = {}, AudioSamples = {}, Assets = {} } },
    FlashMemory0 = flash,
    RealityChip0 = rtc,
    Speaker0 = { State = true },
    AudioChip0 = { Play = function() end },
    PowerButton = { ButtonState = false },
  }

  return {
    video = video, cpu = cpu, flash = flash, logs = logs,
    saved = function() return saved end,
  }
end

-- Simulate one touch tick: down/move/up edges then update().
function M.tick(stub, opts)
  opts = opts or {}
  local v = stub.video
  if opts.pos then v.TouchPosition = vec2(opts.pos[1], opts.pos[2]) end
  v.TouchDown = opts.down == true
  v.TouchUp = opts.up == true
  if opts.down then v.TouchState = true end
  if opts.up then v.TouchState = false end
  stub.cpu.Time = stub.cpu.Time + stub.cpu.DeltaTime
  update()
  v.TouchDown = false
  v.TouchUp = false
end

function M.tap(stub, x, y)
  M.tick(stub, { pos = { x, y }, down = true })
  M.tick(stub, { pos = { x, y }, up = true })
end

function M.key(name, down)
  eventChannel1(gdt.KeyboardChip0, {
    ButtonDown = down ~= false,
    ButtonUp = down == false,
    InputName = name,
    Type = "KeyboardChipEvent",
  })
end

function M.typeText(s)
  local upper = {}
  for c = 97, 122 do upper[string.char(c)] = string.char(c - 32) end
  for i = 1, #s do
    local ch = s:sub(i, i)
    local name
    if upper[ch] then name = upper[ch]
    elseif ch:match("%d") then name = "Alpha" .. ch
    elseif ch == " " then name = "Space"
    else
      local rev = { ["-"]="Minus", ["="]="Equals", ["["]="LeftBracket",
        ["]"]="RightBracket", ["\\"]="Backslash", [";"]="Semicolon",
        ["'"]="Quote", [","]="Comma", ["."]="Period", ["/"]="Slash",
        ["`"]="BackQuote" }
      name = rev[ch]
    end
    if name then
      M.key(name, true); M.key(name, false)
    end
  end
end

return M
