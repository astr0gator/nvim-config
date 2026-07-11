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

-- Case 7: <Tab>/<S-Tab> cell-to-cell navigation on an EXISTING table with a
-- wrapped row. Regression (2026-07-10): next_cell/prev_cell used to
-- delegate to vim-table-mode's own tablemode#spreadsheet#cell#Motion — but
-- this config deliberately never calls tablemode#Enable() (it maps `|` in
-- insert mode and turns on CursorHold auto-align, both of which corrupt
-- non-table lines — see the comment in config() above), so that engine's
-- internal column cache was never initialized. Confirmed by direct testing:
-- calling it on an already-aligned, non-wrapped table produced non-monotonic
-- jumps (col 10 → 2 → 33 → 23 instead of stepping through columns in
-- order) — landing in the wrong cell (e.g. typing into "ai" while aiming for
-- "game on"), which is exactly the corruption this reproduces end to end.
vim.g.table_realign_width = nil
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "| score | name                 | game on | l-value | ai | apa | eo | biztech | created    | closed reason        |",
  "|-------|----------------------|---------|---------|----|-----|----|---------|------------|----------------------|",
  "| 5     | dealcraft            | 10      | 3       | 2  | 2   | 6  | 6       | 2026-07-09 | no founder-market    |",
  "|       |                      |         |         |    |     |    |         |            | fit, too many weak   |",
  "|       |                      |         |         |    |     |    |         |            | rings in a chain,    |",
  "|       |                      |         |         |    |     |    |         |            | not apa, not ai      |",
  "| 2     | make something       |         |         |    |     |    |         |            |                      |",
  "|       | agents want          |         |         |    |     |    |         |            |                      |",
})

local function press_tab_n()
  vim.fn.maparg("<Tab>", "n", false, true).callback()
end
local function press_shift_tab_n()
  vim.fn.maparg("<S-Tab>", "n", false, true).callback()
end
local function cell_under_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
  return cells_of(line)
end

-- From row 3 cell 1 ("score"="5"), tab forward one cell at a time and check
-- each landing cell in order — must hit every column of row 3 exactly once,
-- never skipping or repeating one (the observed bug: 1→2 landed fine, but
-- 2→3 jumped straight to column 5).
vim.api.nvim_win_set_cursor(0, { 3, 2 }) -- col 2: inside cell 1's content ("5"), not on the leading pipe
press_tab_n()
local case7_expect = { "dealcraft", "10", "3", "2", "2", "6", "6", "2026-07-09", "no founder-market" }
for i, expect in ipairs(case7_expect) do
  local cells = cell_under_cursor()
  local col_idx = i + 1 -- cell 1 was score; this loop checks cells 2..10
  assert_eq(cells[col_idx], expect,
    "case7: tab #" .. i .. " must land in cell " .. col_idx .. " ('" .. expect .. "')")
  if i < #case7_expect then press_tab_n() end
end

-- One more tab from the LAST cell of row 3 must cross the wrapped
-- row-3/4/5/6 continuation lines and land at row 7 cell 1 ("2"), not get
-- stuck on one of the continuation lines in between.
press_tab_n()
assert_eq(cell_under_cursor()[1], "2", "case7: tab past last cell of row 3 lands on row 7 cell 1")

-- Shift-tab back from there must retrace the SAME wrapped boundary and land
-- exactly back on row 3's last cell ("no founder-market"), not one of the
-- continuation lines.
press_shift_tab_n()
assert_eq(cell_under_cursor()[10], "no founder-market",
  "case7: shift-tab back over the wrap boundary lands on row 3's last cell")

-- Case 8: <Leader>tdd/tdc/tic/tiC/tn/tN (delete row/col, insert col, jump
-- first/last row) on a table with wrapped rows. Regression (2026-07-10):
-- these all used to delegate straight to vim-table-mode's own
-- tablemode#spreadsheet#* functions, which have no concept of our
-- word-wrapped continuation rows. Confirmed directly: DeleteRow on a
-- wrapped row deleted almost the ENTIRE table (blanked the header, wiped
-- every other row) instead of just that one row, and MoveToFirstRow/
-- MoveToLastRow landed on a continuation line instead of a genuine row.
-- Same root cause as case 7's Tab bug — see the comment above delete_row
-- in table_mode.lua.
local function press(lhs)
  vim.fn.maparg(lhs, "n", false, true).callback()
end

local function wrapped_table_fixture()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "| score | name                 | game on | l-value | ai | apa | eo | biztech | created    | closed reason        |",
    "|-------|----------------------|---------|---------|----|-----|----|---------|------------|----------------------|",
    "| 5     | dealcraft            | 10      | 3       | 2  | 2   | 6  | 6       | 2026-07-09 | no founder-market    |",
    "|       |                      |         |         |    |     |    |         |            | fit, too many weak   |",
    "|       |                      |         |         |    |     |    |         |            | rings in a chain,    |",
    "|       |                      |         |         |    |     |    |         |            | not apa, not ai      |",
    "| 2     | make something       |         |         |    |     |    |         |            |                      |",
    "|       | agents want          |         |         |    |     |    |         |            |                      |",
  })
end

-- DeleteRow on the wrapped "dealcraft" row (spans 4 physical lines): must
-- remove ONLY that logical row, leaving the header/separator and the
-- "make something / agents want" row untouched.
wrapped_table_fixture()
vim.api.nvim_win_set_cursor(0, { 3, 2 })
press("<Leader>tdd")
local r8a = buf_lines()
assert_eq(#r8a, 4, "case8: DeleteRow removes exactly the 4 physical lines of the wrapped row")
assert_eq(cells_of(r8a[1])[1], "score", "case8: DeleteRow leaves the header intact")
local remaining = {}
for _, line in ipairs(r8a) do
  if not is_sep_row(line) then
    local c2 = cells_of(line)[2]
    if c2 and c2 ~= "" then remaining[#remaining + 1] = c2 end
  end
end
assert_eq(table.concat(remaining, " "):find("make something", 1, true) ~= nil, true,
  "case8: DeleteRow leaves the OTHER row's text intact")
assert_eq(table.concat(remaining, " "):find("dealcraft", 1, true) ~= nil, false,
  "case8: DeleteRow actually removed the targeted row's text")

-- DeleteRow must be a no-op on the header row (nothing to delete there).
wrapped_table_fixture()
local before8 = buf_lines()
vim.api.nvim_win_set_cursor(0, { 1, 2 })
press("<Leader>tdd")
assert_eq(buf_lines(), before8, "case8: DeleteRow is a no-op on the header row")

-- DeleteColumn on "game on" (col 3): must vanish from header, separator, AND
-- every data/continuation row, with every row still equal width.
wrapped_table_fixture()
vim.api.nvim_win_set_cursor(0, { 3, 33 }) -- inside "10", the game-on cell
press("<Leader>tdc")
local r8b = buf_lines()
assert_eq(cells_of(r8b[1]), { "score", "name", "l-value", "ai", "apa", "eo", "biztech", "created", "closed reason" },
  "case8: DeleteColumn removes 'game on' from the header")
local width8b = #r8b[1]
for i, line in ipairs(r8b) do
  assert_eq(#line, width8b, "case8: DeleteColumn row " .. i .. " still matches table width")
end

-- InsertColumn after "name" (col 2): header/data/continuation rows all gain
-- an extra empty column right after "name", and stay equal width.
wrapped_table_fixture()
vim.api.nvim_win_set_cursor(0, { 3, 10 }) -- inside "dealcraft", the name cell
press("<Leader>tic")
local r8c = buf_lines()
assert_eq(cells_of(r8c[1])[3], "", "case8: InsertColumn adds an empty column right after 'name'")
assert_eq(cells_of(r8c[1])[4], "game on", "case8: InsertColumn doesn't disturb the column after that")
local width8c = #r8c[1]
for i, line in ipairs(r8c) do
  assert_eq(#line, width8c, "case8: InsertColumn row " .. i .. " still matches table width")
end

-- MoveToLastRow from the header must land on the true last DATA row (score
-- "2"), not a continuation line (e.g. row 8, which only has "agents want").
wrapped_table_fixture()
vim.api.nvim_win_set_cursor(0, { 1, 2 })
press("<Leader>tN")
assert_eq(cell_under_cursor()[1], "2", "case8: MoveToLastRow lands on the real last row, not a continuation line")

-- MoveToFirstRow from a continuation line must land on the true first DATA
-- row (score "5"), not stay stuck on/near the header or a continuation line.
wrapped_table_fixture()
vim.api.nvim_win_set_cursor(0, { 8, 2 })
press("<Leader>tn")
assert_eq(cell_under_cursor()[1], "5", "case8: MoveToFirstRow lands on the real first row")

print("ok: table creation tests passed (incl. no-leading-pipe header)")
