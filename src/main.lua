-- ==========================================================================
-- PocketOS main — Retro Gadgets CPU entry point.
--
-- Add every file in src/ to your gadget as a Code asset named after the file
-- (e.g. "hal" for hal.lua), set this file as the CPU Source, and wire the
-- CPU's EventChannel 1 to KeyboardChip0 in the Multitool (also attempted in
-- code below). See README.md for the full module shopping list.
-- ==========================================================================

local hal    = require("hal")
local theme  = require("theme")
local gfx    = require("gfx")
local keymap = require("keymap")
local fs     = require("fs")
local WM     = require("wm")
local Shell  = require("shell")
local apps   = require("appbase")

local AppTerminal = require("app_terminal")
local AppFiles    = require("app_files")
local AppPaint    = require("app_paint")
local AppSettings = require("app_settings")
local AppAbout    = require("app_about")

-- boot ----------------------------------------------------------------------
gfx.init(hal, theme)
fs.init(hal)
fs.load()

local wm = WM.new({ hal = hal, theme = theme, gfx = gfx })

local env = {
  hal = hal, theme = theme, gfx = gfx,
  fs = fs, wm = wm, apps = apps,
}
local shell = Shell.new(env)
env.shell = shell

apps.register({ id = "terminal", title = "Terminal", glyph = ">_",
  w = 96, h = 56, open = function(e) return AppTerminal.new(e) end })
apps.register({ id = "files", title = "Files", glyph = "[f]",
  w = 92, h = 60, open = function(e) return AppFiles.new(e) end })
apps.register({ id = "paint", title = "Paint", glyph = "(*)",
  w = 90, h = 60, open = function(e) return AppPaint.new(e) end })
apps.register({ id = "settings", title = "Settings", glyph = "[*]",
  w = 80, h = 60, open = function(e) return AppSettings.new(e) end })
apps.register({ id = "about", title = "About", glyph = "(?)",
  w = 80, h = 70, open = function(e) return AppAbout.new(e) end })

-- keyboard event channel -> KeyboardChip0 (Multitool wiring is authoritative)
hal.bindChannel(1, hal.kbd)

-- Debug/test handle (also handy for live inspection from the Multitool).
PocketOS = { wm = wm, shell = shell, env = env, fs = fs }

local shifted = false
local lastX, lastY = -1, -1

log("PocketOS booted: " .. hal.W .. "x" .. hal.H)

-- per-tick ------------------------------------------------------------------
function update()
  local v = hal.video
  local pos = v.TouchPosition
  if v.TouchDown then
    shell:touchDown(pos.X, pos.Y)
  elseif v.TouchState and (pos.X ~= lastX or pos.Y ~= lastY) then
    shell:touchMove(pos.X, pos.Y)
  end
  if v.TouchUp then
    shell:touchUp(pos.X, pos.Y)
  end
  lastX, lastY = pos.X, pos.Y

  shell:update()
  shell:draw()
end

-- keyboard events ------------------------------------------------------------
function eventChannel1(sender, event)
  if type(event) ~= "table" then return end
  local name = keymap.normalize(event.InputName)
  if event.ButtonDown and keymap.isShift(name) then shifted = true end
  if event.ButtonUp and keymap.isShift(name) then shifted = false end
  local char = nil
  if event.ButtonDown then char = keymap.char(name, shifted) end
  shell:key(name, char, event.ButtonDown == true)
end
