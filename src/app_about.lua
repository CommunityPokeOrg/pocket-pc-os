-- PocketOS About app: system info.
local M = {}
local T, g, fs, hal

function M.new(env)
  T, g, fs, hal = env.theme, env.gfx, env.fs, env.hal
  local inst = {}
  setmetatable(inst, { __index = M })
  return inst
end

function M:draw(ctx)
  local u = fs.usage()
  local lines = {
    "PocketOS 0.1",
    "a Pocket PC for Retro Gadgets",
    "",
    "display " .. hal.W .. "x" .. hal.H,
    "uptime " .. string.format("%.0fs", hal.time()),
    hal.rtc and "RTC present" or "no RTC chip",
    fs.isPersistent() and
      string.format("flash %d/%d bytes", u.used, u.capacity) or
      "no flash chip",
    "",
    "(c) CommunityPoke",
  }
  for i = 1, #lines do
    g.textClip(ctx.x + 2, ctx.y + (i - 1) * (T.fontH + 1), lines[i],
      ctx.w - 4, T.pal.black)
  end
end

return M
