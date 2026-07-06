-- Test markdown table creation on <Tab>, incl. headers WITHOUT a leading pipe
-- (e.g. "score | name | ..."). Reproduces the user-facing flow end-to-end.

vim.g.mapleader = " "

local spec = dofile(vim.fn.getcwd() .. "/lua/plugins/editor/table_mode.lua")
spec.init()   -- sets vim.g.table_mode_* vars, disables plugin default mappings
spec.config() -- registers the FileType markdown autocmd

-- Fire the autocmd so the buffer-local <Tab>/<S-Tab>/<leader>t* maps are set.
vim.bo.filetype = "markdown"

local function assert_eq(actual, expected, label)
  if vim.deep_equal(actual, expected) then return end
  error(("%s\nexpected: %s\nactual:   %s"):format(label, vim.inspect(expected), vim.inspect(actual)))
end

local function set_line(line)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- row 1, 0-based col 0
end

local function buf_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function press_tab()
  local info = vim.fn.maparg("<Tab>", "n", false, true)
  assert_eq(type(info.callback), "function", "<Tab> normal-mode callback exists")
  info.callback()
end

-- Case 1: header WITHOUT a leading pipe converts (the restored convenience).
set_line("score | name | l-value | ai | apa | eo | biztech |")
press_tab()
local r1 = buf_lines()
assert_eq(#r1 >= 3, true, "case1: created header+separator+data (>=3 rows)")
assert_eq(r1[2]:match("^|[%s%-:]+|") ~= nil, true, "case1: row 2 is a separator")
-- Regression guard: parse_cells used to drop the first column on a
-- no-leading-pipe header. Every header cell must survive into the rendered row.
for _, col in ipairs({ "score", "name", "l-value", "ai", "apa", "eo", "biztech" }) do
  assert_eq(r1[1]:find(col, 1, true) ~= nil, true, "case1: header keeps column '" .. col .. "'")
end

-- Case 2: header WITH a leading pipe still converts (no regression).
set_line("| alpha | beta | gamma |")
press_tab()
local r2 = buf_lines()
assert_eq(#r2 >= 3, true, "case2: created >=3 rows")
assert_eq(r2[1]:find("alpha", 1, true) ~= nil, true, "case2: keeps 'alpha'")
assert_eq(r2[1]:find("gamma", 1, true) ~= nil, true, "case2: keeps 'gamma'")

-- Case 3: a SHORT header (<4 pipes, no leading |) does NOT convert — guards
-- against turning prose like "foo | bar | baz" into a table. Use an explicit
-- leading | for short tables.
set_line("foo | bar | baz")
press_tab()
local r3 = buf_lines()
assert_eq(#r3, 1, "case3: short no-leading-pipe line (<4 pipes) left alone")
assert_eq(r3[1], "foo | bar | baz", "case3: line intact")

-- Case 4: plain prose with NO pipe is left alone (Tab falls through, no table).
set_line("just some prose with no pipe here")
press_tab()
local r4 = buf_lines()
assert_eq(#r4, 1, "case4: prose not turned into a table (still 1 row)")
assert_eq(r4[1], "just some prose with no pipe here", "case4: prose text intact")

print("ok: table creation tests passed (incl. no-leading-pipe header)")
