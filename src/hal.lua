-- PocketOS HAL: resolves gadget modules from gdt.* once, tolerating optional
-- hardware. Everything else in the OS talks to this table, never to gdt.
local hal = {}

local function first(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v ~= nil then return v end
  end
  return nil
end

hal.video   = gdt.VideoChip0
hal.cpu     = first(gdt.CPU0, gdt.CPU)
hal.kbd     = gdt.KeyboardChip0
hal.rom     = gdt.ROM
hal.flash   = first(gdt.FlashMemory0, gdt.FlashMemory)
hal.rtc     = first(gdt.RealityChip0, gdt.RealityChip)
hal.audio   = gdt.AudioChip0
hal.speaker = first(gdt.Speaker0, gdt.Speaker)

assert(hal.video, "PocketOS requires a VideoChip (gdt.VideoChip0)")
assert(hal.cpu, "PocketOS requires a CPU (gdt.CPU0)")

hal.W = hal.video.Width
hal.H = hal.video.Height

-- ROM may be absent on stripped-down builds; the OS falls back to no-font mode
-- only in the test harness, in a real gadget add a ROM for StandardFont.
hal.font = nil
if hal.rom and hal.rom.System and hal.rom.System.SpriteSheets then
  hal.font = hal.rom.System.SpriteSheets["StandardFont"]
end

function hal.time()
  return hal.cpu.Time
end

function hal.dt()
  return hal.cpu.DeltaTime
end

-- Returns an os.date-style table or nil when no RealityChip is present.
function hal.datetime()
  if hal.rtc and hal.rtc.GetDateTime then
    local ok, t = pcall(function() return hal.rtc:GetDateTime() end)
    if ok and type(t) == "table" then return t end
  end
  return nil
end

function hal.beep()
  -- Placeholder hook for future AudioChip UI sounds; safe no-op without one.
end

-- Wire a CPU event channel to a module. Works at runtime on RG builds that
-- allow it; otherwise the user wires it in the Multitool (see README).
function hal.bindChannel(n, module)
  if hal.cpu and hal.cpu.EventChannels then
    pcall(function() hal.cpu.EventChannels[n] = module end)
  end
end

return hal
