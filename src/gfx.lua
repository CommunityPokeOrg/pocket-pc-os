-- PocketOS gfx: thin drawing layer over VideoChip. All coordinates are ints.
-- The VideoChip has no scissor/clip API, so widgets clip text themselves via
-- textClip and must stay inside their content rects.
local M = {}

local video, font, T

function M.init(hal, theme)
  video = hal.video
  font = hal.font
  T = theme
end

local function v2(x, y)
  return vec2(math.floor(x + 0.5), math.floor(y + 0.5))
end

function M.rect(x, y, w, h, c)
  if w <= 0 or h <= 0 then return end
  video:FillRect(v2(x, y), v2(x + w - 1, y + h - 1), c)
end

function M.frame(x, y, w, h, c)
  if w <= 0 or h <= 0 then return end
  video:DrawRect(v2(x, y), v2(x + w - 1, y + h - 1), c)
end

-- Classic raised/sunken 1px bevel used for taskbar, buttons and window faces.
function M.bevel(x, y, w, h, raised)
  local lt, dk
  if raised then
    lt, dk = T.pal.light, T.pal.shade
  else
    lt, dk = T.pal.shade, T.pal.light
  end
  video:DrawLine(v2(x, y), v2(x + w - 1, y), lt)
  video:DrawLine(v2(x, y), v2(x, y + h - 1), lt)
  video:DrawLine(v2(x, y + h - 1), v2(x + w - 1, y + h - 1), dk)
  video:DrawLine(v2(x + w - 1, y), v2(x + w - 1, y + h - 1), dk)
end

function M.text(x, y, s, fg, bg)
  if not font or not s or s == "" then return end
  video:DrawText(v2(x, y), font, s, fg, bg or color.clear)
end

-- Truncates s to fit inside w pixels (approximate: fontW per char).
function M.fit(s, w)
  local max = math.floor(w / T.fontW)
  if max < 1 then return "" end
  if #s > max then
    if max <= 1 then return string.sub(s, 1, max) end
    return string.sub(s, 1, max - 2) .. ".."
  end
  return s
end

function M.textClip(x, y, s, w, fg, bg)
  M.text(x, y, M.fit(s, w), fg, bg)
end

function M.button(x, y, w, h, label, down)
  M.rect(x, y, w, h, T.pal.face)
  M.bevel(x, y, w, h, not down)
  if label and label ~= "" then
    local tx = x + math.max(1, math.floor((w - #label * T.fontW) / 2))
    local ty = y + math.max(1, math.floor((h - T.fontH) / 2))
    M.textClip(tx, ty, label, w - 2, T.pal.black)
  end
end

-- Inclusive point-in-rect test.
function M.hit(x, y, rx, ry, rw, rh)
  return x >= rx and y >= ry and x < rx + rw and y < ry + rh
end

return M
