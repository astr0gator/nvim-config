-- Test scroll keymaps.
--
-- zz/zt/zb are NATIVE Vim commands: they scroll the CONTENT so the current line
-- is centered / top / bottom, and they leave the cursor on the same line. The old
-- config remapped them to H/M/L, which instead JUMP the cursor — that is the bug
-- these tests guard against. zz must never be remapped to a cursor-moving motion.

-- Load the real keymaps.lua so the test guards the actual config file.
dofile(vim.fn.getcwd() .. "/lua/config/keymaps.lua")

local function assert_eq(actual, expected, label)
  if vim.deep_equal(actual, expected) then return end
  error(("%s\nexpected: %s\nactual:   %s"):format(label, vim.inspect(expected), vim.inspect(actual)))
end

-- zz/zt/zb must NOT be remapped — maparg returns "" for native (unmapped) keys.
-- This is the direct regression guard: re-adding `map("n","zz","M",...)` fails here.
for _, key in ipairs({ "zt", "zz", "zb" }) do
  local rhs = vim.fn.maparg(key, "n", false, true).rhs or "" -- "" (or nil) = native
  assert_eq(rhs, "", key .. " must be native, not remapped to H/M/L")
end

-- Build a tall buffer and a short window so centering is observable.
local lines = {}
for i = 1, 60 do lines[i] = ("line %d"):format(i) end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.api.nvim_win_set_height(0, 10)
local height = vim.api.nvim_win_get_height(0)

-- zz must scroll the content so the cursor line is centered WITHOUT moving the
-- cursor to a different line. `:normal` (no bang) processes mappings, so if zz
-- were ever remapped to M the cursor would jump and this assertion would fail.
vim.api.nvim_win_set_cursor(0, { 40, 0 })
vim.cmd.normal("zz")
local after_zz = vim.api.nvim_win_get_cursor(0)[1]
assert_eq(after_zz, 40, "zz must NOT move the cursor to a different line")

local topline = vim.fn.line("w0")
local screen_row = after_zz - topline + 1 -- 1-based row of the cursor within the window
local lo, hi = math.floor(height / 2), math.ceil(height / 2) + 1
assert_eq(
  screen_row >= lo and screen_row <= hi,
  true,
  ("zz should center the cursor line (screen_row=%d, want %d..%d)"):format(screen_row, lo, hi)
)

-- Contrast: native M still JUMPS the cursor to the window's middle line. This
-- proves zz (keep cursor) and M (move cursor) are genuinely different behaviors.
-- Land the cursor on the topline first (H), so M has to move it to the middle.
vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- top of buffer; window shows 1..height
vim.cmd.normal("H")
local before_M = vim.api.nvim_win_get_cursor(0)[1]
assert_eq(before_M, 1, "H should land the cursor on the topline")
vim.cmd.normal("M")
local after_M = vim.api.nvim_win_get_cursor(0)[1]
assert_eq(after_M ~= before_M, true, "M should move the cursor to window middle (contrast with zz)")

-- Buffer cycle mappings still set by keymaps.lua (unchanged by this work).
for _, t in ipairs({ { "<S-h>", "<cmd>bprevious<CR>" }, { "<S-l>", "<cmd>bnext<CR>" } }) do
  local info = vim.fn.maparg(t[1], "n", false, true)
  assert_eq(info.rhs, t[2], t[1] .. " rhs")
end

print("ok: scroll keymap tests passed (zz/zt/zb native; zz keeps cursor, centers content)")
