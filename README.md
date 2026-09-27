# PocketOS

A Pocket PC–style operating system for [Retro Gadgets](https://store.steampowered.com/app/1730260/Retro_Gadgets/), written in Lua against the `gdt.*` module API. It gives a gadget a desktop with draggable windows, a taskbar with a Start menu and clock, a persistent filesystem, and a small suite of apps — all rendered through a VideoChip, no custom art assets required.

## Architecture

```
main.lua         CPU entry point: update(), eventChannel1, boot, input routing
shell.lua        Desktop icons, taskbar (Start + window buttons + clock), Start menu
wm.lua           Window manager: focus/z-order, titlebar drag, close box, app dispatch
appbase.lua      App registry used by the desktop and Start menu
app_terminal.lua Command shell: help echo ls cat write rm touch date uptime ver clear exit
app_files.lua    File browser with preview strip, New/Del
app_paint.lua    Stylus paint canvas, 8-color palette, saves to fs
app_settings.lua Wallpaper, clock format, sound, storage reset (persisted)
app_about.lua    System info: resolution, uptime, RTC/flash presence
hal.lua          Hardware abstraction over gdt.*; tolerates missing optional chips
gfx.lua          Drawing helpers (rects, bevels, clipped text, buttons)
theme.lua        Palette + layout metrics
fs.lua           Flat-path virtual filesystem persisted via FlashMemory
keymap.lua       KeyboardChipEvent.InputName → typed characters + shift tracking
```

Data flow per tick: `update()` reads `VideoChip.TouchState/TouchDown/TouchUp/TouchPosition` and routes stylus input to the shell (taskbar → Start menu → windows → desktop icons). `eventChannel1` receives `KeyboardChipEvent`s, tracks shift state, maps `InputName` to characters, and forwards them to the focused window's app.

## Building the gadget

Required modules:

| Module | Purpose |
| --- | --- |
| CPU (medium or large) | runs the OS; medium gives 16 event channels |
| VideoChip | framebuffer; the OS reads `Width`/`Height` so any screen layout works |
| Screen(s) | e.g. two joined 64×36 screens for a 128×72 pocket display |
| KeyboardChip | typing in the terminal, Esc closes the focused window |
| ROM | provides `gdt.ROM.System.SpriteSheets["StandardFont"]` for all text |
| PowerButton | every gadget needs one |

Optional but supported: **FlashMemory** (file + settings persistence; without it storage is RAM-only), **RealityChip** (real clock in the taskbar and `date` command), **Speaker** (Settings → Sound toggle).

### Wiring

1. Add every file under `src/` as a **Code** asset named after the file minus the extension (`hal`, `theme`, `gfx`, `keymap`, `fs`, `wm`, `shell`, `appbase`, `app_terminal`, `app_files`, `app_paint`, `app_settings`, `app_about`).
2. Set `main.lua` as the CPU's **Source**.
3. Point the CPU's **EventChannel 1** at `KeyboardChip0` in the Multitool (the code also attempts `cpu.EventChannels[1] = kbd` at boot, but the Multitool wiring is authoritative).
4. Power on.

## Controls

- **Tap** an icon or Start-menu row to open an app; **drag** a title bar to move a window; tap the `x` box or press **Esc** to close.
- Taskbar buttons raise their window; the clock reads the RealityChip (or uptime without one).
- Terminal keys type into the focused window; Paint accepts keys `1`–`8` for palette selection.

## Developing / validating headlessly

The OS is plain Lua 5.1 (no Luau-only syntax), so it runs under LuaJIT against a stub of the gadget API that implements a real framebuffer and FlashMemory round-trips:

```sh
luajit tests/run.lua
```

`tests/rg_stub.lua` stubs `gdt.*`, `vec2`, `color`, and `log`; `tests/run.lua` parses every source file, boots the OS, and scripts stylus/keyboard interaction end-to-end (icon tap → window open → titlebar drag → Start menu → terminal commands → flash persistence → settings toggle → paint save). 36 assertions, exits non-zero on failure.

## API notes / limitations

- The VideoChip has **no clipping/scissor** primitive — widgets stay inside their content rects and text is width-truncated (`gfx.fit`). `theme.fontW/fontH` (4×8) are conservative StandardFont metrics; tune them if text spacing looks off on real hardware.
- Screens joined around a VideoChip appear as one framebuffer; the OS adapts to `video.Width/Height`, with layouts sized for ≥128×72.
- `require()` resolves gadget Code assets by name, so module names are flat — keep them unique per gadget.

## License

MIT — see [LICENSE](LICENSE).
