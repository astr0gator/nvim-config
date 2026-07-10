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

local function realign_table()
  local info = vim.fn.maparg("<leader>tr", "n", false, true)
  assert_eq(type(info.callback), "function", "<leader>tr normal-mode callback exists")
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

-- Case 5: previous hard-wrap output is rejoined by default. Continuation rows
-- with an empty first cell made separators look like they jumped:
-- | key | desk@ourdomain "as authorized |
-- |     | representative of Client      |
vim.g.table_realign_width = nil
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "| Category | Manual incumbent | Risk |",
  "| --- | --- | --- |",
  "| SaaS | desk@ourdomain \"as authorized | low |",
  "|      | representative of Client |     |",
})
vim.api.nvim_win_set_cursor(0, { 3, 0 })
realign_table()
local r5 = buf_lines()
assert_eq(#r5, 3, "case5: default realign rejoins continuation rows instead of hard-wrapping")
assert_eq(r5[3]:find("authorized representative", 1, true) ~= nil, true,
  "case5: continuation text is folded back into the logical row")

-- Case 6: a column whose HEADER cell is the widest thing in it (wider than
-- every data cell) must not desync the header's width from the rest of the
-- table once that column word-wraps. Regression (2026-07-10, real-world
-- repro in sub_directions.md, a header cell reading "Evidence — who's
-- paying, real numbers"): emit(header) bypassed wordwrap entirely, so the
-- header line came out at its raw (unwrapped) width while separator/data
-- rows in the same column were padded/wrapped to the column's word-wrapped
-- width — every row after the header landed narrower, breaking pipe
-- alignment for the whole table. See reference_lazy-reload.md memory, fact 3.
vim.g.table_realign_width = 40
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "| AB | Evidence of a long header phrase that must wrap | Z |",
  "| --- | --- | --- |",
  "| ab | short | z |",
})
vim.api.nvim_win_set_cursor(0, { 1, 0 })
realign_table()
local r6 = buf_lines()

-- Invariant: every physical row in an aligned block is padded to the same
-- total width. This is the check that would have caught the regression
-- directly — the header row came out longer than every other row.
local width6 = #r6[1]
for i, line in ipairs(r6) do
  assert_eq(#line, width6, "case6: row " .. i .. " (" .. line .. ") must match table width " .. width6)
end

-- The header's full text must survive across however many physical lines it
-- wrapped into — nothing silently dropped or truncated by the wrap. Read
-- column 2 back out of each physical header line (up to the separator) and
-- rejoin, rather than a raw substring search — the pipe-delimited columns
-- around it (e.g. "Z", "ab") would otherwise break a naive whole-row search.
local function cells_of(line)
  local trimmed = line:gsub("^%s*|", ""):gsub("|%s*$", "")
  local out = {}
  for c in vim.gsplit(trimmed, "|", { plain = true }) do
    out[#out + 1] = c:gsub("^%s*(.-)%s*$", "%1")
  end
  return out
end
local function is_sep_row(line)
  local cs = cells_of(line)
  if #cs == 0 then return false end
  local has_dash = false
  for _, c in ipairs(cs) do
    if not c:match("^[%-:%s]*$") then return false end -- a real cell, not all dashes/colons/space
    if c:match("%-") then has_dash = true end
  end
  return has_dash
end
local header_parts = {}
for _, line in ipairs(r6) do
  if is_sep_row(line) then break end -- separator row: header block ends here
  local col2 = cells_of(line)[2]
  if col2 and col2 ~= "" then header_parts[#header_parts + 1] = col2 end
end
assert_eq(table.concat(header_parts, " "), "Evidence of a long header phrase that must wrap",
  "case6: full header text present, in order, across its wrapped lines")

-- Idempotency: realigning again must not drift/grow the table. This catches
-- the companion bug — a wrapped header's continuation line (empty first
-- cell) getting misfiled as a brand-new DATA row on the next pass, since at
-- parse time no data rows existed yet for the old "fold into logical" check
-- to match against.
realign_table()
local r6b = buf_lines()
assert_eq(r6b, r6, "case6: realign is idempotent (no drift/duplication on repeated runs)")

vim.g.table_realign_width = nil

print("ok: table creation tests passed (incl. no-leading-pipe header)")
