-- PocketOS theme: palette and layout metrics (Pocket PC / Windows CE inspired).
local M = {}

-- Layout metrics. fontW/fontH are the assumed StandardFont advance; the real
-- glyphs are proportional, so treat these as conservative layout bounds.
M.fontW = 4
M.fontH = 8
M.taskbarH = 11
M.titleH = 9
M.border = 1
M.iconW = 34
M.iconH = 26
M.menuRowH = 10

-- Wallpaper candidates the Settings app cycles through.
M.wallpapers = {
  { name = "Teal",   c = nil }, -- filled below
  { name = "Navy",   c = nil },
  { name = "Plum",   c = nil },
  { name = "Black",  c = nil },
}

M.pal = {
  desktop  = Color(0, 128, 128),
  face     = Color(192, 192, 192),
  light    = Color(255, 255, 255),
  shade    = Color(128, 128, 128),
  dark     = Color(64, 64, 64),
  black    = color.black,
  white    = color.white,
  titleOn  = Color(0, 0, 168),
  titleOff = Color(128, 128, 128),
  selBg    = Color(0, 0, 128),
  termBg   = Color(0, 0, 48),
  termFg   = Color(80, 255, 80),
  warn     = Color(200, 32, 32),
}

M.wallpapers[1].c = M.pal.desktop
M.wallpapers[2].c = Color(16, 32, 96)
M.wallpapers[3].c = Color(96, 32, 96)
M.wallpapers[4].c = color.black

-- 8-color paint palette (index 1 is also the eraser).
M.paintPal = {
  color.white, color.black, color.red, color.yellow,
  color.green, color.cyan, color.blue, color.magenta,
}

return M
