-- Test visual markdown format mappings.

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

local function trigger_visual_map(lhs)
  local info = vim.fn.maparg(lhs, "v", false, true)
  assert_eq(type(info.callback), "function", lhs .. " callback")
  info.callback()
end

local function feed_keys(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

set_selection("hello", 1, 5)
trigger_visual_map("<leader>h")
assert_eq(vim.api.nvim_get_current_line(), "==hello==", "<leader>h wraps selection")

set_selection("==hello==", 1, 9)
trigger_visual_map("<leader>h")
assert_eq(vim.api.nvim_get_current_line(), "hello", "<leader>h unwraps selected markers")

set_selection("==hello==", 3, 7)
trigger_visual_map("<leader>h")
assert_eq(vim.api.nvim_get_current_line(), "hello", "<leader>h unwraps surrounding markers")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "==hello==" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
feed_keys("vee h")
assert_eq(vim.api.nvim_get_current_line(), "hello", "<leader>h unwraps existing highlight from visual keys")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- Area:" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
feed_keys("V h")
assert_eq(vim.api.nvim_get_current_line(), "==- Area:==", "<leader>h wraps whole line from linewise visual mode")

print("ok: markdown format mapping tests passed")
