-- Test markdown format mappings (<leader>e group): visual + normal mode.
-- Keystroke (feed_keys) cases go last: they leave nvim in visual mode (their
-- <Esc> is queued), and the direct-callback cases below require normal mode.

vim.g.mapleader = " "
dofile(vim.fn.getcwd() .. "/lua/config/keymaps.lua")

local function assert_eq(actual, expected, label)
  if vim.deep_equal(actual, expected) then
    return
  end

  error(
    ("%s\nexpected: %s\nactual:   %s"):format(
      label,
      vim.inspect(expected),
      vim.inspect(actual)
    )
  )
end

local function set_selection(line, start_col, end_col)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  vim.fn.setpos("'<", { 0, 1, start_col, 0 })
  vim.fn.setpos("'>", { 0, 1, end_col, 0 })
end

local function set_line(line, col0)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, col0 }) -- 0-based col
end

local function trigger_map(lhs, mode)
  local info = vim.fn.maparg(lhs, mode, false, true)
  assert_eq(type(info.callback), "function", lhs .. " (" .. mode .. ") callback")
  info.callback()
end

local function feed_keys(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

-- ── Visual mode via marks (stays in normal mode) ──
set_selection("hello", 1, 5)
trigger_map("<leader>eh", "v")
assert_eq(vim.api.nvim_get_current_line(), "==hello==", "<leader>eh wraps selection")

set_selection("==hello==", 1, 9)
trigger_map("<leader>eh", "v")
assert_eq(vim.api.nvim_get_current_line(), "hello", "<leader>eh unwraps selected markers")

set_selection("==hello==", 3, 7)
trigger_map("<leader>eh", "v")
assert_eq(vim.api.nvim_get_current_line(), "hello", "<leader>eh unwraps surrounding markers")

set_selection("hello", 1, 5)
trigger_map("<leader>eb", "v")
assert_eq(vim.api.nvim_get_current_line(), "**hello**", "<leader>eb wraps selection")

set_selection("hello", 1, 5)
trigger_map("<leader>ec", "v")
assert_eq(vim.api.nvim_get_current_line(), "`hello`", "<leader>ec wraps selection")

-- ── Normal mode: word under cursor, repeat toggles ──
set_line("foo bar baz", 4) -- cursor on 'b' of bar
trigger_map("<leader>eb", "n")
assert_eq(vim.api.nvim_get_current_line(), "foo **bar** baz", "<leader>eb bolds word under cursor")

trigger_map("<leader>eb", "n")
assert_eq(vim.api.nvim_get_current_line(), "foo bar baz", "<leader>eb toggles bold off")

set_line("foo bar baz", 4)
trigger_map("<leader>ei", "n")
assert_eq(vim.api.nvim_get_current_line(), "foo *bar* baz", "<leader>ei italicizes word under cursor")

set_line("foo bar baz", 4)
trigger_map("<leader>ec", "n")
assert_eq(vim.api.nvim_get_current_line(), "foo `bar` baz", "<leader>ec codes word under cursor")

set_line("hello, world", 0)
trigger_map("<leader>eb", "n")
assert_eq(vim.api.nvim_get_current_line(), "**hello**, world", "<leader>eb does not grab trailing comma")

set_line("foo bar baz", 5) -- cursor mid-word, on 'a' of bar
trigger_map("<leader>eb", "n")
assert_eq(vim.api.nvim_get_current_line(), "foo **bar** baz", "<leader>eb works from mid-word")

set_line("**foo** bar **baz**", 8) -- both neighbors already bold
trigger_map("<leader>eb", "n")
assert_eq(vim.api.nvim_get_current_line(), "**foo** **bar** **baz**", "<leader>eb bolds between two bold words")

-- ── Keystroke flows (leave nvim in visual mode — kept last) ──
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "==hello==" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
feed_keys("vee eh")
assert_eq(vim.api.nvim_get_current_line(), "hello", "<leader>eh unwraps existing highlight from visual keys")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- Area:" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
feed_keys("V eh")
assert_eq(vim.api.nvim_get_current_line(), "==- Area:==", "<leader>eh wraps whole line from linewise visual mode")

print("ok: markdown format mapping tests passed")
