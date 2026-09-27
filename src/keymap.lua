-- PocketOS keymap: translates KeyboardChipEvent.InputName into typed
-- characters and named special keys. Shift state is tracked by the OS from
-- key events, so this module is pure lookup.
local M = {}

local unshifted = {
  Space = " ", Tab = "\t",
  Minus = "-", Equals = "=", LeftBracket = "[", RightBracket = "]",
  Backslash = "\\", Semicolon = ";", Quote = "'", Comma = ",",
  Period = ".", Slash = "/", BackQuote = "`",
}
local shifted = {
  Minus = "_", Equals = "+", LeftBracket = "{", RightBracket = "}",
  Backslash = "|", Semicolon = ":", Quote = '"', Comma = "<",
  Period = ">", Slash = "?", BackQuote = "~",
}

local digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
local digitShift = { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" }
for i = 1, 10 do
  unshifted["Alpha" .. (i - 1)] = digits[i]
  shifted["Alpha" .. (i - 1)] = digitShift[i]
end

for c = 65, 90 do
  local name = string.char(c) -- "A".."Z"
  unshifted[name] = string.char(c + 32)
  shifted[name] = string.char(c)
end

-- InputName may arrive as "A" or "KeyboardChip.A" depending on firmware;
-- normalize to the bare name.
function M.normalize(inputName)
  local s = tostring(inputName)
  s = s:gsub("^KeyboardChip%.", "")
  return s
end

-- Returns the typed character, or nil for non-printable keys.
function M.char(inputName, isShifted)
  local name = M.normalize(inputName)
  local t = isShifted and shifted or unshifted
  return t[name] or unshifted[name]
end

function M.isShift(inputName)
  local n = M.normalize(inputName)
  return n == "LeftShift" or n == "RightShift"
end

-- Named keys apps care about: Return, Backspace, Escape, arrows, Delete...
function M.isSpecial(inputName, want)
  return M.normalize(inputName) == want
end

return M
