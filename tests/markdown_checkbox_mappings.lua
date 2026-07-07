-- Test markdown checkbox mappings provided by the bullets plugin config.
_G.close_current_buffer = function() end
vim.bo.filetype = "markdown"

local spec = dofile(vim.fn.getcwd() .. "/lua/plugins/editor/bullets.lua")
spec.init()
spec.config()

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

local function set_buffer(lines, cursor)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, cursor)
end

local function run_case(case)
  set_buffer(case.lines, case.cursor)
  local map = vim.fn.maparg(case.trigger, "n", false, true)
  map.callback()
  vim.wait(20)
  local actual = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert_eq(actual, case.expected, case.name)
  assert_eq(vim.api.nvim_win_get_cursor(0), case.expected_cursor, case.name .. " cursor")
end

local cases = {
  {
    name = "ta adds checkbox on empty line",
    lines = { "" },
    cursor = { 1, 0 },
    trigger = "ta",
    expected = { "[ ] " },
    expected_cursor = { 1, 3 },
  },
  {
    name = "ta converts plain text line into a checkbox without losing text",
    lines = { "foo" },
    cursor = { 1, 0 },
    trigger = "ta",
    expected = { "[ ] foo" },
    expected_cursor = { 1, 3 },
  },
  {
    name = "ta preserves unordered list marker",
    lines = { "- foo" },
    cursor = { 1, 0 },
    trigger = "ta",
    expected = { "- [ ] foo" },
    expected_cursor = { 1, 5 },
  },
  {
    name = "to inserts checkbox below with indent preserved",
    lines = { "one", "  two" },
    cursor = { 2, 0 },
    trigger = "to",
    expected = { "one", "  two", "  [ ] " },
    expected_cursor = { 3, 5 },
  },
  {
    name = "tO inserts checkbox above with indent preserved",
    lines = { "one", "  two" },
    cursor = { 2, 0 },
    trigger = "tO",
    expected = { "one", "  [ ] ", "  two" },
    expected_cursor = { 2, 5 },
  },
}

for _, case in ipairs(cases) do
  run_case(case)
end

-- Enter-continuation via _G.markdown_continue_checkbox(): a fresh unchecked
-- `- [ ] ` below, or exit the list when the item is empty. Covers normal-mode
-- Enter and the line-level logic shared with insert-mode Enter.
local continue_cases = {
  {
    name = "Enter on checkbox adds new empty checkbox below",
    lines = { "- [ ] task" },
    cursor = { 1, 0 },
    expected = { "- [ ] task", "- [ ] " },
    expected_cursor = { 2, 5 },
  },
  {
    name = "Enter on checked item adds unchecked checkbox below",
    lines = { "- [x] done" },
    cursor = { 1, 0 },
    expected = { "- [x] done", "- [ ] " },
    expected_cursor = { 2, 5 },
  },
  {
    name = "Enter on empty checkbox exits the list",
    lines = { "- [ ] " },
    cursor = { 1, 0 },
    expected = { "" },
    expected_cursor = { 1, 0 },
  },
  {
    name = "Enter on checkbox preserves indent and marker",
    lines = { "  - [ ] task" },
    cursor = { 1, 0 },
    expected = { "  - [ ] task", "  - [ ] " },
    expected_cursor = { 2, 7 },
  },
  {
    name = "Enter on bare checkbox (no bullet) adds new checkbox below",
    lines = { "[ ] fsdfsd" },
    cursor = { 1, 0 },
    expected = { "[ ] fsdfsd", "[ ] " },
    expected_cursor = { 2, 3 },
  },
  {
    name = "Enter on bare empty checkbox exits the list",
    lines = { "[ ] " },
    cursor = { 1, 0 },
    expected = { "" },
    expected_cursor = { 1, 0 },
  },
}

for _, case in ipairs(continue_cases) do
  set_buffer(case.lines, case.cursor)
  _G.markdown_continue_checkbox()
  vim.wait(20)
  local actual = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert_eq(actual, case.expected, case.name)
  assert_eq(vim.api.nvim_win_get_cursor(0), case.expected_cursor, case.name .. " cursor")
end

print(("ok: %d markdown checkbox mapping tests passed"):format(#cases + #continue_cases))
