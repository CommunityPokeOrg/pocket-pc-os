-- PocketOS headless validation. Run from repo root:  luajit tests/run.lua
local stub = dofile("tests/rg_stub.lua")

local failures = 0
local function ok(cond, name)
  if cond then
    io.write("PASS " .. name .. "\n")
  else
    failures = failures + 1
    io.write("FAIL " .. name .. "\n")
  end
end

-- 1. every source file parses ------------------------------------------------
local srcs = {
  "hal", "theme", "gfx", "keymap", "fs", "wm", "shell", "appbase",
  "app_terminal", "app_files", "app_paint", "app_settings", "app_about",
  "main",
}
for _, n in ipairs(srcs) do
  local f, err = loadfile("src/" .. n .. ".lua")
  ok(f ~= nil, "parse " .. n .. (err and ("  " .. tostring(err)) or ""))
end

-- 2. install the gdt stub + module loader, boot the OS ------------------------
local hw = stub.install(128, 72)

local loaded = {}
function require(name)
  if loaded[name] ~= nil then return loaded[name] end
  local chunk = assert(loadfile("src/" .. name .. ".lua"))
  loaded[name] = chunk() or true
  return loaded[name]
end

dofile("src/main.lua")

ok(type(update) == "function", "update() defined")
ok(type(eventChannel1) == "function", "eventChannel1 defined")

local wm = PocketOS.wm
local shell = PocketOS.shell
local fs = PocketOS.fs

-- 3. first render -------------------------------------------------------------
stub.tick(hw)
ok(hw.video.ops > 0, "update() issues draw ops")
local wp = hw.video:pixelAt(120, 20)
ok(wp ~= nil and wp.g == 128, "wallpaper painted")
ok(hw.video:findText("Start") ~= nil, "taskbar Start button drawn")
ok(hw.video:findText("Terminal") ~= nil, "desktop icons drawn")

-- 4. open a window via desktop icon -------------------------------------------
-- icon layout: iconW=30, iconH=26, 4px gaps, 2px margin; rows of iconH+4.
-- icons (col-major): Terminal@(2,2) Files@(2,32) Paint@(2,62) wraps to col 1...
stub.tap(hw, 10, 10)
stub.tick(hw)
ok(wm:count() == 1, "tap icon opens one window")
ok(wm:focused() and wm:focused().title == "Terminal", "Terminal window focused")

-- 5. drag the window by its title bar -----------------------------------------
local win = wm:focused()
local ox, oy = win.x, win.y
stub.tick(hw, { pos = { win.x + 20, win.y + 3 }, down = true })
stub.tick(hw, { pos = { win.x + 35, win.y + 18 }, move = true })
stub.tick(hw, { pos = { win.x + 35, win.y + 18 }, up = true })
ok(win.x == ox + 15 and win.y == oy + 15, "titlebar drag moves window")

-- 6. focus follows the window button in the taskbar ---------------------------
stub.tap(hw, 40, 68) -- empty desktop -> nothing new
ok(wm:count() == 1, "desktop tap does not open window")

-- 7. open Terminal is already open; launch Files through the Start menu -------
local taskY = hw.video.Height - 11
stub.tap(hw, 5, taskY + 4)                    -- Start button
stub.tick(hw)
ok(shell.menuOpen, "start menu opens")
stub.tap(hw, 20, taskY - (#loaded["appbase"].list) * 10 - 4 + 12 + 1) -- row 2 (Files)
stub.tick(hw)
ok(wm:count() == 2, "start menu launches Files")
ok(wm:focused().title == "Files", "Files focused")

-- 8. terminal keyboard input ---------------------------------------------------
wm:focus(wm.wins[1]) -- refocus Terminal
local term = wm:focused().inst
stub.typeText("echo hi")
stub.key("Return", true)
stub.tick(hw)
local joined = table.concat(term.lines, "\n")
ok(joined:find("hi", 1, true) ~= nil, "terminal echo output")
stub.typeText("write /t.txt abc")
stub.key("Return", true)
ok(fs.read("/t.txt") == "abc", "terminal write persists to fs")

-- 9. flash memory persistence ---------------------------------------------------
local saved = hw.saved()
ok(saved ~= nil and saved.files and saved.files["/t.txt"] == "abc",
  "FlashMemory Save round-trips the volume")

-- 10. Escape closes the focused window ------------------------------------------
stub.key("Escape", true)
stub.tick(hw)
ok(wm:count() == 1, "Escape closes focused window")

-- 11. close box on titlebar removes window --------------------------------------
win = wm:focused()
local cx = win.x + win.w - 6
stub.tap(hw, cx, win.y + 4)
stub.tick(hw)
ok(wm:count() == 0, "close box removes window")

-- 12. settings toggle via app -----------------------------------------------------
shell:launch("settings")
stub.tick(hw)
local inst = wm:focused().inst
local before = shell.clockFmt24
inst:touchDown(4, 2 + (2 - 1) * 12 + 2, wm:content(wm:focused())) -- row 2: clock
ok(shell.clockFmt24 ~= before, "settings toggles clock format")
ok(fs.getSetting("clock24") == shell.clockFmt24, "setting persisted")

-- 13. paint draws and saves -------------------------------------------------------
wm:closeInst(inst)
shell:launch("paint")
stub.tick(hw)
inst = wm:focused().inst
local ctx = wm:content(wm:focused())
inst:touchDown(5, 14, ctx) -- canvas area (below 12px palette strip)
inst:touchMove(8, 16, ctx)
stub.tick(hw)
ok(inst.grid ~= nil and inst.grid[2][6] == 2 and inst.grid[4][9] == 2,
  "paint plots pixels")
inst:touchDown(ctx.w - 5, 2, ctx) -- SAV button
ok(fs.read("/paint_1.img") ~= nil, "paint saves to fs")

io.write(failures == 0 and "ALL TESTS PASSED\n" or
  (failures .. " FAILURE(S)\n"))
os.exit(failures == 0 and 0 or 1)
