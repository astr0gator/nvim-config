-- Pure engine for markdown pipe-table editing: parse / layout / emit.
-- Everything here maps line arrays to line arrays (or operates on the parsed
-- structure in between) — no buffer, window, or cursor access — so every
-- transformation is unit-testable and every table mutation (realign, sort,
-- column CRUD) flows through the ONE parse→emit pipeline instead of
-- re-deriving wrap logic per operation. See init.lua for the design contract
-- (in particular the wrapped-continuation-row model this file implements).

local M = {}

-- Markdown inline markup whose delimiters get concealed on render
-- (treesitter markdown_inline conceal, active at conceallevel=2):
-- bold/italic markers, strikethrough, code-span backticks, and link
-- syntax collapsing to just its text. Padding must be sized to this
-- rendered width, not raw source width — confirmed live: a cell like
-- `thesis_dealcraft.md` lines up correctly in insert mode (backticks
-- visible) but the trailing pipe drifts 2 cols left in normal mode
-- once the backticks conceal, since raw-width padding didn't budget
-- for the 2 chars that vanish on render.
local function strip_concealed(s)
  s = s:gsub("%[([^%]]+)%]%([^%)]+%)", "%1") -- [text](url) -> text
  s = s:gsub("%*%*([^*]+)%*%*", "%1")        -- **bold**
  s = s:gsub("__([^_]+)__", "%1")            -- __bold__
  s = s:gsub("~~([^~]+)~~", "%1")            -- ~~strike~~
  s = s:gsub("`([^`]+)`", "%1")              -- `code`
  s = s:gsub("%*([^*]+)%*", "%1")            -- *italic*
  s = s:gsub("_([^_]+)_", "%1")              -- _italic_
  return s
end

-- Display width of a string (multibyte-aware) — this is what makes a cell
-- line up on screen. Padding by byte length breaks on unicode.
-- NOTE: use nvim_strwidth, not strdisplaywidth() — the latter returns
-- inconsistent values for long unicode strings in nvim 0.11.x (e.g. a
-- 346-cell measures 359), which breaks uniform padding.
local function cellwidth(s) return vim.api.nvim_strwidth(strip_concealed(s)) end
M.cellwidth = cellwidth

-- Split a table row into trimmed cell contents, dropping the outer pipes.
-- Handles rows with or without a leading/trailing pipe and preserves empty
-- interior cells. Internal runs of whitespace are collapsed to a single
-- space, which also self-heals cells a past realign over-padded.
function M.parse_row(line)
  local s = line:gsub("^%s*|%s*", ""):gsub("%s*|%s*$", "")
  local cells = {}
  for c in vim.gsplit(s, "|", { plain = true, trimempty = false }) do
    cells[#cells + 1] = (c:gsub("^%s*(.-)%s*$", "%1"):gsub("%s+", " "))
  end
  return cells
end

-- A continuation row (the hard-wrap remainder of the logical row above,
-- produced by emit_block's own word-wrap): empty first cell, but at least
-- one OTHER cell has content. A row that's empty in EVERY cell (e.g. a
-- freshly-appended blank row) is a real row, not a continuation. Single
-- source of truth for parse_block (which folds continuation rows back into
-- the row above) and init.lua's row navigation, which must skip them.
function M.is_continuation_cells(cells)
  if cells[1] ~= "" then return false end
  for i = 2, #cells do
    if cells[i] ~= "" then return true end
  end
  return false
end

-- A separator row: every cell is only dashes/colons/space, at least one dash.
function M.is_separator_cells(cells)
  if #cells == 0 then return false end
  local has_dash = false
  for _, c in ipairs(cells) do
    if not c:match("^[%-:%s]*$") then return false end
    if c:match("%-") then has_dash = true end
  end
  return has_dash
end

function M.is_separator_line(line)
  return M.is_separator_cells(M.parse_row(line))
end

-- Parse a block of physical lines into header / separator / data rows, and
-- rejoin hard-wrapped continuation rows (those whose first cell is empty)
-- back into the logical row above. Returns a mutable structure
-- {header, sep_cells, align, logical, ncols} — realign feeds this straight
-- to emit_block, while sort/delete_column/insert_column edit it in place
-- first. header_row/last_row are tracked by reference (not just the header
-- array) so a continuation line can fold into the HEADER too, not only into
-- a previous data row: the header wraps across several physical lines
-- exactly like data rows (see emit_block), and without this its 2nd+
-- physical line — first cell empty, same shape as any other continuation
-- row — would otherwise fail the "#logical > 0" guard (no data rows exist
-- yet) and get misfiled as a brand-new data row on the very next realign.
function M.parse_block(lines)
  local header_row, sep_cells, align = nil, {}, {}
  local logical = {}
  local last_row = nil
  for _, line in ipairs(lines) do
    if line:match("^%s*$") then
      -- stray blank line inside the block; skip it — the table is
      -- regenerated without it
    else
      local cells = M.parse_row(line)
      if M.is_separator_cells(cells) then
        sep_cells = cells
        for ci, c in ipairs(cells) do
          local l, r = c:sub(1, 1) == ":", c:sub(-1) == ":"
          align[ci] = (l and r) and "c" or (r and "r") or "l"
        end
      elseif not header_row and #logical == 0 then
        header_row = { cells = cells }
        last_row = header_row
      elseif last_row and M.is_continuation_cells(cells) then
        -- continuation row: fold into the previous header/data row.
        for ci = 2, #cells do
          local add = cells[ci] or ""
          if add ~= "" then
            last_row.cells[ci] = (last_row.cells[ci] == "" and add or last_row.cells[ci] .. " " .. add)
          end
        end
      else
        local row = { cells = cells }
        logical[#logical + 1] = row
        last_row = row
      end
    end
  end
  local header = header_row and header_row.cells or {}

  local ncols = 0
  for _, row in ipairs(logical) do ncols = math.max(ncols, #row.cells) end
  ncols = math.max(ncols, #header, #sep_cells)

  return { header = header, sep_cells = sep_cells, align = align, logical = logical, ncols = ncols }
end

-- Word-wrap text to a display width, breaking on spaces.
local function wordwrap(text, w)
  if text == "" then return { "" } end
  local out, line = {}, ""
  for word in text:gmatch("%S+") do
    if line == "" then line = word
    elseif cellwidth(line) + 1 + cellwidth(word) <= w then line = line .. " " .. word
    else out[#out + 1] = line; line = word end
  end
  out[#out + 1] = line
  return out
end

-- Compute column widths/wrapping for a parsed block and return it as final
-- buffer lines: header (wrapped as needed), separator, then each data row
-- (wrapped as needed).
--
-- Fit the table to wrap_width (normally the window's text area): narrow
-- columns pad to their widest cell so the pipes line up (the normal look),
-- and if that would exceed the window the widest columns word-wrap into the
-- column instead (Notion/org-mode style). A wrapped entry spans several
-- physical rows with empty key cells on the continuation lines.
-- render-markdown's pipe_table renderer draws box-drawing borders over this
-- fine, as long as column width accounts for concealed markup (see
-- cellwidth/strip_concealed above) so its overlay and our raw text agree on
-- width. parse_block rejoins continuation rows before re-wrapping, so
-- formatting is idempotent across saves.
--
-- grace > 0 lets tables overflow wrap_width by that many columns before
-- wrapping kicks in (for users who'd rather scroll than wrap).
function M.emit_block(parsed, wrap_width, grace)
  local header, sep_cells, align, logical, ncols =
    parsed.header, parsed.sep_cells, parsed.align, parsed.logical, parsed.ncols

  -- Widest cell per column across header + (rejoined) data rows.
  local maxw = {}
  local function track(ci, c)
    if c then maxw[ci] = math.max(maxw[ci] or 1, cellwidth(c)) end
  end
  for ci = 1, ncols do track(ci, header[ci]) end
  for _, row in ipairs(logical) do
    for ci = 1, #row.cells do track(ci, row.cells[ci]) end
  end

  -- Decide which columns wrap so the table fits wrap_width. Narrow columns
  -- keep their full width (pipes align); the widest columns wrap (prose)
  -- and share the width left over. A table that already fits wraps nothing.
  -- wrap[ci] is a boolean; colw[ci] is the column's render width either way.
  -- Concealed markup (backticks, **bold**, etc.) adds raw characters that
  -- vanish on render but still count toward the buffer's actual physical
  -- line length — Neovim's line-wrap operates on that raw length, not the
  -- rendered one. Budget for the worst-case row's concealed overhead so a
  -- table with e.g. backtick-wrapped cells doesn't overflow the window by
  -- those invisible chars and get its trailing pipe raggedly soft-wrapped
  -- onto its own line.
  local function raw_extra(s) return vim.api.nvim_strwidth(s) - cellwidth(s) end
  local function row_overhead(cells)
    local sum = 0
    for _, c in ipairs(cells) do sum = sum + raw_extra(c) end
    return sum
  end
  local max_overhead = row_overhead(header)
  for _, row in ipairs(logical) do
    max_overhead = math.max(max_overhead, row_overhead(row.cells))
  end

  local MIN_WRAP = 20
  local overhead = 3 * ncols + 1 + max_overhead -- pipes/padding + worst-case concealed-markup slack
  local avail = wrap_width - overhead
  local order = {}
  for ci = 1, ncols do order[ci] = ci end
  table.sort(order, function(a, b) return (maxw[a] or 0) < (maxw[b] or 0) end)
  local fullw_total = 0
  for ci = 1, ncols do fullw_total = fullw_total + (maxw[ci] or 0) end
  local wrap, n_wrap = {}, 0
  if fullw_total + overhead > wrap_width + (grace or 0) then
    for idx = #order, 1, -1 do -- widest first: shed columns into wrap until it fits
      if fullw_total + n_wrap * MIN_WRAP <= avail then break end
      local ci = order[idx]
      fullw_total = fullw_total - (maxw[ci] or 0)
      wrap[ci] = true
      n_wrap = n_wrap + 1
    end
  end
  local colw = {}
  if n_wrap > 0 then
    local per = math.max(MIN_WRAP, math.floor((avail - fullw_total) / n_wrap))
    for ci = 1, ncols do
      colw[ci] = wrap[ci] and math.min(per, maxw[ci] or per) or (maxw[ci] or 1)
    end
  else
    for ci = 1, ncols do colw[ci] = maxw[ci] or 1 end
  end

  local out = {}
  local function emit(cells)
    local parts = {}
    for ci = 1, ncols do
      local c = cells[ci] or ""
      local pad = string.rep(" ", math.max(0, colw[ci] - cellwidth(c)))
      if align[ci] == "r" then c = pad .. c
      elseif align[ci] == "c" then
        local lp = math.floor(#pad / 2)
        c = string.rep(" ", lp) .. c .. string.rep(" ", #pad - lp)
      else c = c .. pad end
      parts[ci] = " " .. c .. " "
    end
    out[#out + 1] = "|" .. table.concat(parts, "|") .. "|"
  end

  -- Wrap-then-emit a logical row: word-wraps any column marked wrap[ci] to
  -- colw[ci], expanding it to as many physical lines as its tallest cell
  -- needs (continuation lines get "" in the other columns). Used for BOTH
  -- the header and data rows so the header can never end up wider than the
  -- columns everything else is padded to — an earlier version emitted the
  -- header raw/unwrapped, so a long header cell in a wrapped column
  -- overflowed past colw while data/separator rows stayed narrow, breaking
  -- column alignment for the whole table.
  local function emit_wrapped(cells)
    local lines_per, height = {}, 1
    for ci = 1, ncols do
      local c = cells[ci] or ""
      lines_per[ci] = wrap[ci] and wordwrap(c, colw[ci]) or { c }
      if #lines_per[ci] > height then height = #lines_per[ci] end
    end
    for li = 1, height do
      local out_cells = {}
      for ci = 1, ncols do
        out_cells[ci] = lines_per[ci][li] or ""
      end
      emit(out_cells)
    end
  end

  emit_wrapped(header)
  -- separator row (dashes sized to each column's width)
  do
    local parts = {}
    for ci = 1, ncols do
      local w = colw[ci]
      local sc = sep_cells[ci] or ""
      if align[ci] == "c" then parts[ci] = ":" .. string.rep("-", w) .. ":"
      elseif align[ci] == "r" then parts[ci] = string.rep("-", w + 1) .. ":"
      elseif align[ci] == "l" and sc:sub(1, 1) == ":" then parts[ci] = ":" .. string.rep("-", w + 1)
      else parts[ci] = string.rep("-", w + 2) end
    end
    out[#out + 1] = "|" .. table.concat(parts, "|") .. "|"
  end
  -- data rows — a wrapped logical row expands to several physical rows
  for _, row in ipairs(logical) do
    emit_wrapped(row.cells)
  end
  return out
end

-- Sort the parsed block's LOGICAL data rows in place, keyed on column
-- col_idx. Continuation lines were already folded into their logical row by
-- parse_block, so a wrapped cell can never be separated from its row by the
-- sort — the whole reason this replaces :TableSort (vim-table-mode's sort
-- treats every physical line as an independent row and scrambles
-- continuation lines away from their rows). Numeric-aware: when both keys
-- parse as numbers they compare numerically ("2" < "10"), otherwise
-- case-insensitive string compare. Stable (original order breaks ties), so
-- repeated sorts don't shuffle equal-keyed rows.
function M.sort_rows(parsed, col_idx, desc)
  local decorated = {}
  for i, row in ipairs(parsed.logical) do
    decorated[i] = { row = row, idx = i, key = row.cells[col_idx] or "" }
  end
  table.sort(decorated, function(a, b)
    local na, nb = tonumber(a.key), tonumber(b.key)
    local lt, gt
    if na and nb then
      lt, gt = na < nb, na > nb
    else
      local la, lb = a.key:lower(), b.key:lower()
      lt, gt = la < lb, la > lb
    end
    if lt or gt then
      if desc then return gt else return lt end
    end
    return a.idx < b.idx
  end)
  for i, d in ipairs(decorated) do parsed.logical[i] = d.row end
end

return M
