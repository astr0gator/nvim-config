-- Markdown pipe-table editing, self-contained. Buffer/cursor/keymap layer on
-- top of core.lua (the pure parse→layout→emit engine).
--
-- ── Design contract (read this before touching table behavior) ─────────────
--
-- 1. NO PLUGIN. This replaced dhruvasagar/vim-table-mode entirely
--    (2026-07-11). History of why: the plugin's supported mode
--    (tablemode#Enable()) maps `|` in insert mode to auto-tableize and
--    auto-realigns on CursorHold — both corrupt any line that merely
--    contains a `|` (markdown links, shell pipes in code spans). With
--    Enable() never called, every tablemode#* function and :Table* command
--    ran against an UNINITIALIZED engine that doesn't error — it just does
--    something quietly wrong (DeleteRow once wiped nearly a whole table;
--    cell motion jumped columns non-monotonically). Months of piecemeal
--    fixes kept rediscovering this one keymap at a time. Do not reintroduce
--    the plugin or any tablemode#/:Table* delegation.
--
-- 2. WRAPPED CONTINUATION ROWS. Wide free-text cells word-wrap to the
--    window width (Notion/org-mode style): one LOGICAL row spans several
--    PHYSICAL lines, the 2nd+ lines having an empty first cell ("
--    continuation rows"). This is a bespoke convention of this config — GFM
--    itself is one-cell-per-line — and it renders correctly because
--    render_markdown.lua keeps tables as raw text and this code owns
--    alignment. EVERY operation here must therefore think in logical rows:
--    parse_block folds continuation lines into their row; navigation and
--    row CRUD skip/carry them.
--
-- 3. ONE PIPELINE. Every mutation (realign, sort, row/column CRUD) goes
--    parse_block → mutate parsed → emit_block. Never hand-edit physical
--    lines for a structural change — per-operation emit logic is how the
--    header-wrap desync bug happened.
--
-- 4. TESTS. tests/table_create.lua pins all of this end-to-end (creation,
--    realign idempotency, equal-width invariant, cell motion across wrap
--    boundaries, row/column CRUD, sort, cell start/end). Any new operation
--    needs a case there, exercised against a table WITH wrapped rows — the
--    bugs this file exists to prevent are invisible on small hand-typed
--    tables in a wide terminal.
--
-- Knobs: vim.g.table_realign_width caps table width (default: window text
-- area); vim.g.table_realign_grace lets tables overflow by that many
-- columns before wrapping kicks in (if you'd rather scroll than wrap).

local core = require("config.markdown_table.core")

local M = {}

-- ── Buffer predicates ───────────────────────────────────────────────────

local function on_table_row()
  local line = vim.api.nvim_get_current_line()
  if line:sub(1, 1) ~= "|" then return false end
  local _, count = line:gsub("%|", "|")
  return count >= 2
end

-- The contiguous `|`-block around the cursor.
local function block_around_cursor()
  local lnum = vim.fn.line(".")
  local last = vim.fn.line("$")
  local top, bot = lnum, lnum
  while top > 1 and vim.fn.getline(top - 1):sub(1, 1) == "|" do top = top - 1 end
  while bot < last and vim.fn.getline(bot + 1):sub(1, 1) == "|" do bot = bot + 1 end
  return top, bot
end

-- Are we inside an existing table? Find the contiguous block of lines
-- starting with `|` around the cursor and check whether it contains a
-- separator row. The cursor's OWN line must be in the scan: when the
-- cursor rests on the separator row (which happens naturally, since
-- Tab from the header's last cell lands on `|---|`), scanning only the
-- neighbors misses the separator and create_table() would fire,
-- duplicating the separator and inserting a bogus empty row.
local function in_existing_table()
  if not on_table_row() then return false end
  local top, bot = block_around_cursor()
  for i = top, bot do
    if vim.fn.getline(i):find("^|[%s%-:]+|") then return true end
  end
  return false
end

local function is_separator_row(lnum)
  return core.is_separator_line(vim.fn.getline(lnum))
end

-- ── Realign ─────────────────────────────────────────────────────────────

local function wrap_width()
  -- vim.g.table_realign_width overrides with a fixed cap. Default: the
  -- window's actual text area, uncapped — always use the full window width,
  -- however wide the monitor. getwininfo().textoff is nvim's own count of
  -- the gutter (line numbers + sign column + fold column), so this fits the
  -- table precisely inside what's visible — no soft-wrapping the closing
  -- pipe past the edge. -1 leaves the closing pipe one cell inside the
  -- window.
  local w = vim.g.table_realign_width
  if w then return w end
  local wi = vim.fn.getwininfo(vim.fn.win_getid())[1]
  local textw = wi and (wi.width - wi.textoff) or vim.o.columns
  return math.max(40, textw - 1)
end

-- Realign the contiguous block of `|` rows from top..bot so every column is
-- padded to its widest cell (by display width) and every row ends up
-- identical width. Separator rows (`---`/`:--:`/`---:`) are detected per
-- column to preserve left/right/center alignment hints.
local function realign_block(top, bot)
  local lines = vim.api.nvim_buf_get_lines(0, top - 1, bot, false)
  local out = core.emit_block(core.parse_block(lines), wrap_width(), vim.g.table_realign_grace or 0)
  -- nvim_buf_set_lines (not setline): the row count changes when a prose
  -- column wraps, so the replaced range must be exact.
  vim.api.nvim_buf_set_lines(0, top - 1, bot, false, out)
end

-- Safe realign of the table under the cursor: only when it's a proper
-- table (a `|`-block containing a separator row). Never touches lines
-- that merely contain `|` but aren't a real table.
local function safe_realign()
  if not in_existing_table() then return end
  local top, bot = block_around_cursor()
  realign_block(top, bot)
end

-- Realign every proper table in the buffer (for the save autocmd, so a
-- multi-table file stays tidy without visiting each table). Processed
-- bottom-up: realigning a block changes line counts, so blocks at higher
-- line numbers go first and don't shift the offsets of the rest.
local function realign_all_tables()
  local last = vim.fn.line("$")
  local blocks = {}
  local i = 1
  local function has_sep(a, b)
    for ln = a, b do
      if vim.fn.getline(ln):find("^|[%s%-:]+|") then return true end
    end
    return false
  end
  while i <= last do
    if vim.fn.getline(i):sub(1, 1) ~= "|" then
      i = i + 1
    else
      local top = i
      while i <= last and vim.fn.getline(i):sub(1, 1) == "|" do i = i + 1 end
      local bot = i - 1
      -- A stray blank line can split one table into two |-runs. If the
      -- next |-run (across blank lines) has no separator of its own, it's a
      -- continuation of THIS table — fold it in so realign regenerates the
      -- table as one block (dropping the blank line). A genuine second
      -- table carries its own separator and is left alone.
      while true do
        local j = i
        while j <= last and vim.fn.getline(j):match("^%s*$") do j = j + 1 end
        if j > last or vim.fn.getline(j):sub(1, 1) ~= "|" then break end
        local k = j
        while k <= last and vim.fn.getline(k):sub(1, 1) == "|" do k = k + 1 end
        if has_sep(j, k - 1) then break end
        bot = k - 1
        i = k
      end
      if has_sep(top, bot) then blocks[#blocks + 1] = { top, bot } end
    end
  end
  for b = #blocks, 1, -1 do realign_block(blocks[b][1], blocks[b][2]) end
end

-- ── Cursor/column primitives ────────────────────────────────────────────

-- column_index counts the pipes strictly before the cursor, which is
-- exactly the 1-based cell number (1 pipe before cursor ⇒ in cell 1,
-- 2 pipes ⇒ cell 2, ...); goto_column is its inverse, landing 2 cols past
-- the col_idx'th pipe (the space-padded start of that cell).
local function column_index()
  local before = vim.api.nvim_get_current_line():sub(1, vim.fn.col(".") - 1)
  local _, n = before:gsub("|", "")
  return n
end

local function goto_column(lnum, col_idx)
  local line = vim.fn.getline(lnum)
  local pipes_seen, target = 0, 1
  for i = 1, #line do
    if line:sub(i, i) == "|" then
      pipes_seen = pipes_seen + 1
      if pipes_seen == col_idx then target = i + 2; break end
    end
  end
  vim.fn.cursor(lnum, target)
end

-- Byte span (start, end inclusive) of the cursor's cell content area on the
-- CURRENT physical line — the region between its two pipes, excluding them.
local function cell_bounds()
  local line = vim.api.nvim_get_current_line()
  local n = math.max(1, column_index())
  local pipes = {}
  for i = 1, #line do
    if line:sub(i, i) == "|" then pipes[#pipes + 1] = i end
  end
  local p = pipes[n]
  if not p then return nil end
  local q = pipes[n + 1] or (#line + 1)
  if q - p < 2 then return nil end
  return p + 1, q - 1
end

-- ── Cell start/end/position (used to be the last vim-table-mode calls) ──

local function cell_start()
  if not on_table_row() then return end
  local s, e = cell_bounds()
  if not s then return end
  local seg = vim.api.nvim_get_current_line():sub(s, e)
  local first = seg:find("%S")
  vim.fn.cursor(vim.fn.line("."), first and (s + first - 1) or (s + 1))
end

local function cell_end()
  if not on_table_row() then return end
  local s, e = cell_bounds()
  if not s then return end
  local seg = vim.api.nvim_get_current_line():sub(s, e)
  local last = seg:find("%S%s*$")
  vim.fn.cursor(vim.fn.line("."), last and (s + last - 1) or (s + 1))
end

-- Echo the cursor's LOGICAL cell position as "(row, col)": row counts
-- logical data rows below the separator (a wrapped row's continuation
-- lines report the row they belong to), row 0 = header, col = cell number.
local function echo_cell()
  if not in_existing_table() then return end
  local top, bot = block_around_cursor()
  local lnum = vim.fn.line(".")
  local sep_lnum = nil
  for i = top, bot do
    if is_separator_row(i) then sep_lnum = i; break end
  end
  local row = 0
  if sep_lnum and lnum > sep_lnum then
    for i = sep_lnum + 1, lnum do
      if not core.is_continuation_cells(core.parse_row(vim.fn.getline(i))) then row = row + 1 end
    end
  end
  local col = math.max(1, column_index())
  vim.api.nvim_echo({ { ("table cell (%d, %d)"):format(row, col) } }, true, {})
end

-- ── Table creation on <Tab> ─────────────────────────────────────────────

-- Lenient header check for CREATION only: a line with ≥4 pipes that isn't
-- already a |...| table row. Lets headers without a leading pipe (e.g.
-- "score | name | ...") convert on Tab. The 4-pipe floor avoids misfiring
-- on prose that merely contains a pipe — a bare "a | b" is left alone; use
-- an explicit leading | (| a | b |) for short tables. Can't be inside a
-- table here (on_table_row is false ⇒ no leading |).
local function looks_like_header()
  local _, count = vim.api.nvim_get_current_line():gsub("%|", "|")
  return count >= 4
end

-- Decide what <Tab> does: "create" (start/extend a table), "next" (move to
-- the next cell), or nil (fall through to the key default). Creation is
-- lenient (looks_like_header); navigation stays strict (on_table_row ⇒
-- leading |) so Tab never misfires on prose mid-table.
local function tab_target()
  if on_table_row() then
    return in_existing_table() and "next" or "create"
  elseif looks_like_header() then
    return "create"
  end
end

-- Parse a header line into cells: {text, width}
local function parse_cells(line)
  line = line:gsub("%s*$", ""):gsub("|%s*$", "")
  -- Allow headers without a leading pipe (e.g. "score | name | ..."):
  -- the gmatch below keys off a leading |, so synthesize one when absent,
  -- otherwise the first cell ("score") is silently dropped.
  if line:sub(1, 1) ~= "|" then line = "|" .. line end
  local cells = {}
  for cell in line:gmatch("|([^|]*)") do
    local t = cell:gsub("^%s*(.-)%s*$", "%1")
    if #t > 0 then
      cells[#cells + 1] = { text = t, width = math.max(#t, 3) }
    end
  end
  return cells
end

-- Build separator + empty row and insert below header
local function create_table()
  local cells = parse_cells(vim.api.nvim_get_current_line())
  if #cells == 0 then return end
  local h, s, e = {}, {}, {}
  for _, c in ipairs(cells) do
    h[#h + 1] = (" %" .. c.width .. "s "):format(c.text)
    s[#s + 1] = string.rep("-", c.width)
    e[#e + 1] = string.rep(" ", c.width)
  end
  local lnum = vim.fn.line(".")
  vim.fn.setline(lnum, "|" .. table.concat(h, "|") .. "|")
  vim.fn.append(lnum, {
    "|" .. table.concat(s, "|") .. "|",
    "|" .. table.concat(e, "|") .. "|",
  })
  safe_realign()
  vim.fn.cursor(lnum + 2, 1)
  vim.fn.search("|\\s\\zs", "cW")
end

-- ── Row/column CRUD ─────────────────────────────────────────────────────

-- Blank out a row's cell contents while keeping its pipe structure.
-- Parens force gsub's single return value: it also returns a match count,
-- which would otherwise leak into vim.fn.append below as a spurious 3rd
-- argument ("Too many arguments for function: append").
local function blank_row(line)
  return (line:gsub("([^|]+)", function(cell) return string.rep(" ", #cell) end))
end

local function insert_row(below)
  local lnum = vim.fn.line(".")
  local empty = blank_row(vim.fn.getline(lnum))
  vim.fn.append(below and lnum or (lnum - 1), empty)
  vim.fn.cursor(below and (lnum + 1) or lnum, 1)
  safe_realign()
  vim.fn.search("|\\s\\zs", "cW")
end

-- Delete the LOGICAL row under the cursor — every physical line it
-- occupies, including wrapped continuation lines below it — not just the
-- one physical line. No-op on the header/separator — deleting those isn't
-- what "delete row" should mean for a data table.
local function delete_row()
  if not in_existing_table() then return end
  safe_realign()
  local top, bot = block_around_cursor()
  local sep_lnum = nil
  for i = top, bot do
    if is_separator_row(i) then sep_lnum = i; break end
  end
  local lnum = vim.fn.line(".")
  if not sep_lnum or lnum <= sep_lnum then return end
  local rtop = lnum
  while rtop > sep_lnum + 1 and core.is_continuation_cells(core.parse_row(vim.fn.getline(rtop))) do
    rtop = rtop - 1
  end
  local rbot = rtop
  while rbot < bot and core.is_continuation_cells(core.parse_row(vim.fn.getline(rbot + 1))) do
    rbot = rbot + 1
  end
  vim.api.nvim_buf_set_lines(0, rtop - 1, rbot, false, {})
  safe_realign()
  vim.fn.cursor(math.min(rtop, vim.fn.line("$")), 1)
end

-- Parse the block, hand the parsed structure to `mutate` for in-place
-- editing, and re-emit through the same wrap pipeline realign uses (design
-- contract rule 3). Returns the block's top line on success, nil on a
-- no-op, so callers can reposition the cursor.
local function mutate_block(mutate)
  if not in_existing_table() then return nil end
  safe_realign()
  local top, bot = block_around_cursor()
  local col_idx = math.max(1, column_index())
  local lines = vim.api.nvim_buf_get_lines(0, top - 1, bot, false)
  local parsed = core.parse_block(lines)
  if not mutate(parsed, col_idx) then return nil end
  local out = core.emit_block(parsed, wrap_width(), vim.g.table_realign_grace or 0)
  vim.api.nvim_buf_set_lines(0, top - 1, bot, false, out)
  return top
end

local function delete_column()
  local top = mutate_block(function(parsed, col_idx)
    if parsed.ncols <= 1 or col_idx > parsed.ncols then return false end
    table.remove(parsed.header, col_idx)
    table.remove(parsed.sep_cells, col_idx)
    table.remove(parsed.align, col_idx)
    for _, row in ipairs(parsed.logical) do
      table.remove(row.cells, col_idx)
    end
    parsed.ncols = parsed.ncols - 1
    return true
  end)
  if top then goto_column(top, 1) end
end

-- after=true inserts to the RIGHT of the cursor's column, false to the LEFT.
local function insert_column(after)
  local top = mutate_block(function(parsed, col_idx)
    local pos = col_idx + (after and 1 or 0)
    table.insert(parsed.header, pos, "")
    table.insert(parsed.sep_cells, pos, "")
    table.insert(parsed.align, pos, "l")
    for _, row in ipairs(parsed.logical) do
      table.insert(row.cells, pos, "")
    end
    parsed.ncols = parsed.ncols + 1
    return true
  end)
  if top then goto_column(top, 1) end
end

-- Sort data rows by the cursor's column (see core.sort_rows for the
-- numeric-aware, wrap-safe semantics). Lands on the first data row of the
-- sorted table, same column.
local function sort_column(desc)
  local col_idx
  local top = mutate_block(function(parsed, ci)
    col_idx = ci
    core.sort_rows(parsed, ci, desc)
    return true
  end)
  if not top then return end
  local last = vim.fn.line("$")
  local i = top
  while i < last and vim.fn.getline(i):sub(1, 1) == "|" do
    if is_separator_row(i) then
      goto_column(math.min(i + 1, last), col_idx)
      return
    end
    i = i + 1
  end
end

-- Swap the cursor's column with its neighbor (dir=1 right, -1 left). The
-- cursor follows the moved column so repeated presses keep shoving it.
local function swap_col(dir)
  local target_col
  local top = mutate_block(function(parsed, col_idx)
    local target = col_idx + dir
    if target < 1 or target > parsed.ncols or col_idx > parsed.ncols then return false end
    target_col = target
    local function swap(t) t[col_idx], t[target] = t[target], t[col_idx] end
    swap(parsed.header)
    swap(parsed.sep_cells)
    swap(parsed.align)
    for _, row in ipairs(parsed.logical) do swap(row.cells) end
    return true
  end)
  if top then goto_column(vim.fn.line("."), target_col) end
end

-- ── Navigation ──────────────────────────────────────────────────────────

-- Jump to the first/last genuine DATA row (skipping the header, separator,
-- and any wrapped continuation lines), landing in the same column the
-- cursor started in.
local function move_to_first_row()
  if not in_existing_table() then return end
  safe_realign()
  local top, bot = block_around_cursor()
  local col_idx = math.max(1, column_index())
  local sep_lnum = nil
  for i = top, bot do
    if is_separator_row(i) then sep_lnum = i; break end
  end
  if not sep_lnum or sep_lnum + 1 > bot then return end
  goto_column(sep_lnum + 1, col_idx)
end

local function move_to_last_row()
  if not in_existing_table() then return end
  safe_realign()
  local top, bot = block_around_cursor()
  local col_idx = math.max(1, column_index())
  local target = bot
  while target > top and core.is_continuation_cells(core.parse_row(vim.fn.getline(target))) do
    target = target - 1
  end
  if is_separator_row(target) then return end
  goto_column(target, col_idx)
end

-- Cell-to-cell motion. Walks past separator/continuation rows to find the
-- next/prev genuine row when a move crosses a row boundary.
local function next_cell()
  if not in_existing_table() then return false end
  safe_realign()
  local lnum = vim.fn.line(".")
  local col_idx = column_index()
  local ncols = #core.parse_row(vim.fn.getline(lnum))
  local _, bot = block_around_cursor()
  if col_idx < ncols then
    goto_column(lnum, col_idx + 1)
    return true
  end
  -- Last cell of this physical row. If it's also the table's last row,
  -- grow the table with a blank row.
  if lnum == bot then
    local line = vim.api.nvim_get_current_line()
    vim.fn.append(bot, blank_row(line))
    safe_realign()
    vim.fn.cursor(bot + 1, 3) -- 2 past the leading pipe: start of cell 1
    return true
  end
  -- Wrap to cell 1 of the next genuine row, skipping the separator and any
  -- wrapped continuation lines of a multi-line cell.
  local last = vim.fn.line("$")
  local target = lnum
  while true do
    target = target + 1
    if target > last or vim.fn.getline(target):sub(1, 1) ~= "|" then return true end
    local cells = core.parse_row(vim.fn.getline(target))
    if not is_separator_row(target) and not core.is_continuation_cells(cells) then break end
  end
  goto_column(target, 1)
  return true
end

local function prev_cell()
  if not in_existing_table() then return false end
  safe_realign()
  local lnum = vim.fn.line(".")
  local col_idx = column_index()
  if col_idx > 1 then
    goto_column(lnum, col_idx - 1)
    return true
  end
  -- First cell of this row: step to the LAST cell of the previous genuine
  -- row, skipping separator/continuation lines. No-op at the table's
  -- top-left, matching next_cell's own-boundary shape.
  local top = block_around_cursor()
  if lnum == top then return true end
  local target = lnum
  while true do
    target = target - 1
    if target < 1 or vim.fn.getline(target):sub(1, 1) ~= "|" then return true end
    local cells = core.parse_row(vim.fn.getline(target))
    if not is_separator_row(target) and not core.is_continuation_cells(cells) then break end
  end
  goto_column(target, #core.parse_row(vim.fn.getline(target)))
  return true
end

-- Returns true if handled (cursor was on an existing table row) — even at
-- the table's boundary (a genuine no-op there). false means "not in a
-- table", so the J/K keymaps below fall through to list-item / paragraph
-- motion instead of ever touching table rows.
local function move_row(dir)
  if not in_existing_table() then return false end
  safe_realign()
  local col_idx = column_index()
  local last = vim.fn.line("$")
  local target = vim.fn.line(".")
  while true do
    target = target + dir
    if target < 1 or target > last or vim.fn.getline(target):sub(1, 1) ~= "|" then
      return true -- at the table's edge: no-op, don't fall through to J/K's normal behavior
    end
    local cells = core.parse_row(vim.fn.getline(target))
    if not is_separator_row(target) and not core.is_continuation_cells(cells) then break end
  end
  goto_column(target, col_idx)
  vim.cmd("normal! zz") -- keep the target row in view after jumping past wrapped lines
  return true
end

-- Next/prev list item (bullet or numbered), same idea as move_row but for
-- lists instead of table rows: only fires when the CURRENT line is itself
-- a list item, and only jumps if another list item exists further in that
-- direction — otherwise returns false so J/K fall through to paragraph
-- motion instead of stranding you at the last bullet. Uses
-- _G.markdown_is_list_item (autocmds.lua) so this can never drift out of
-- sync with <CR>'s own list-continuation check.
local function move_list_item(dir)
  if not (_G.markdown_is_list_item and _G.markdown_is_list_item(vim.api.nvim_get_current_line())) then
    return false
  end
  local last = vim.fn.line("$")
  local target = vim.fn.line(".")
  while true do
    target = target + dir
    if target < 1 or target > last then return false end
    local line = vim.fn.getline(target)
    if _G.markdown_is_list_item(line) then
      local prefix = line:match("^%s*[%-%*%+]%s+") or line:match("^%s*%d+[%.%)]%s+")
      vim.fn.cursor(target, (prefix and #prefix or 0) + 1)
      vim.cmd("normal! zz")
      return true
    end
  end
end

-- ── Buffer wiring (keymaps + autocmds), fired per markdown buffer ───────

local function attach(bufnr)
  if vim.b[bufnr].markdown_table_attached then return end
  vim.b[bufnr].markdown_table_attached = true

  local b = { buffer = bufnr, silent = true }
  local bm = function(desc) return vim.tbl_extend("force", b, { desc = desc }) end

  -- ── Table: realign / sort ──
  vim.keymap.set("n", "<Leader>tr", safe_realign, bm("Realign"))
  vim.keymap.set("n", "<Leader>ts", function() sort_column(false) end, bm("Sort column asc"))
  vim.keymap.set("n", "<Leader>tS", function() sort_column(true) end, bm("Sort column desc"))

  -- ── Table: delete/insert ──
  vim.keymap.set("n", "<Leader>tdd", delete_row, bm("Delete row"))
  vim.keymap.set("n", "<Leader>tdc", delete_column, bm("Delete column"))
  vim.keymap.set("n", "<Leader>tic", function() insert_column(true) end, bm("Insert col after"))
  vim.keymap.set("n", "<Leader>tiC", function() insert_column(false) end, bm("Insert col before"))
  vim.keymap.set("n", "<Leader>tir", function() insert_row(true) end, bm("Insert row below"))
  vim.keymap.set("n", "<Leader>tiR", function() insert_row(false) end, bm("Insert row above"))

  -- ── Table: navigate ──
  vim.keymap.set("n", "<Leader>tn", move_to_first_row, bm("First row"))
  vim.keymap.set("n", "<Leader>tN", move_to_last_row, bm("Last row"))
  vim.keymap.set("n", "<Leader>t[", cell_start, bm("Cell start"))
  vim.keymap.set("n", "<Leader>t]", cell_end, bm("Cell end"))
  vim.keymap.set("n", "<Leader>te", echo_cell, bm("Echo cell pos"))

  -- ── Table: swap columns ──
  vim.keymap.set("n", "<Leader>t>", function() swap_col(1) end, bm("Move col right"))
  vim.keymap.set("n", "<Leader>t<", function() swap_col(-1) end, bm("Move col left"))

  -- J/K, not <Leader>-prefixed: this needs to be as fast as Tab, and plain
  -- J/K don't collide with flash.nvim's own keys (s/S/r/R/<c-s> — see
  -- flash.lua). Priority: table row, then list item, then a sensible
  -- non-destructive fallback. Neither falls through to vim's default
  -- join-line / hover-docs: join was clobbering table rows and list items
  -- the user wanted to navigate (dd already covers line deletion), and
  -- hover doesn't move the cursor at all, which made K feel stuck instead
  -- of mirroring J's forward paragraph motion. So both fall back to
  -- paragraph motion — } for J, { for K — which glides smoothly between
  -- heading sections either direction.
  vim.keymap.set("n", "J", function()
    if move_row(1) then return end
    if move_list_item(1) then return end
    vim.cmd("normal! }")
  end, bm("Table row / list item / next paragraph"))
  vim.keymap.set("n", "K", function()
    if move_row(-1) then return end
    if move_list_item(-1) then return end
    vim.cmd("normal! {")
  end, bm("Table row / list item / prev paragraph"))

  -- Exposed so autocmds.lua's normal-mode <CR> and bullets.lua's
  -- insert-mode <CR> can check "are we in a table" FIRST, before their own
  -- checkbox/bullet/fold fallbacks — same composition pattern as
  -- _G.markdown_is_checkbox/_G.markdown_continue_checkbox already use.
  -- Returns true if handled (cursor was on an existing table row).
  _G.markdown_table_enter = function()
    if not in_existing_table() then return false end
    if vim.api.nvim_get_mode().mode == "i" then
      vim.schedule(function()
        vim.cmd("stopinsert")
        next_cell()
        vim.cmd("startinsert")
      end)
    else
      next_cell()
    end
    return true
  end

  vim.keymap.set("n", "<Tab>", function()
    local t = tab_target()
    if t == "create" then create_table()
    elseif t == "next" then next_cell()
    else vim.api.nvim_feedkeys("\22", "n", false) end
  end, vim.tbl_extend("force", b, { desc = "Table: next cell" }))

  vim.keymap.set("i", "<Tab>", function()
    local t = tab_target()
    if not t then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
      return
    end
    vim.schedule(function()
      vim.cmd("stopinsert")
      if t == "create" then create_table() else next_cell() end
      vim.cmd("startinsert")
    end)
  end, vim.tbl_extend("force", b, { desc = "Table: next cell (insert)" }))

  vim.keymap.set("n", "<S-Tab>", function()
    if on_table_row() then prev_cell() end
  end, vim.tbl_extend("force", b, { desc = "Table: prev cell" }))

  vim.keymap.set("i", "<S-Tab>", function()
    if not on_table_row() then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-d>", true, false, true), "n", false)
      return
    end
    vim.schedule(function()
      vim.cmd("stopinsert")
      prev_cell()
      vim.cmd("startinsert")
    end)
  end, vim.tbl_extend("force", b, { desc = "Table: prev cell (insert)" }))

  -- Auto-realign tables on save.
  vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = bufnr,
    desc = "Realign markdown tables before save",
    callback = realign_all_tables,
  })

  -- Also realign once on open, so a table typed/pasted elsewhere (e.g. by
  -- an LLM, or before this module existed) renders correctly immediately
  -- instead of looking broken until the first <Leader>tr or save. This is
  -- purely cosmetic materialization of already-saved content, so clear
  -- 'modified' after — it must not force a save prompt on a file the user
  -- never actually touched.
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    vim.api.nvim_buf_call(bufnr, function()
      realign_all_tables()
      vim.bo[bufnr].modified = false
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("markdown_table", { clear = true }),
    pattern = "markdown",
    callback = function(ev) attach(ev.buf) end,
  })
end

return M
