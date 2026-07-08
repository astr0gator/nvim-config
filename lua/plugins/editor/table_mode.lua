-- Configure markdown table editing helpers via vim-table-mode.
return {
  "dhruvasagar/vim-table-mode",
  ft = "markdown",
  init = function()
    vim.g.table_mode_corner = "|"
    vim.g.table_mode_align_char = ":"
    -- Do NOT set table_mode_always_active — vim-table-mode treats ANY line
    -- starting with | as a table row and will corrupt non-table content.
    -- The plugin's DEFAULT mappings live under <Leader>t* (e.g. <Leader>tr runs
    -- its :TableModeRealign — a buggy aligner that mangles wide/unicode tables).
    -- Disable them, then rebind the SAME <Leader>t* prefix to the safer wrappers
    -- below: they call the plugin's functions directly but route realign through
    -- the custom aligner. Reclaims <Leader>t = "table" with no conflict.
    vim.g.table_mode_disable_mappings = 1
    -- The plugin also auto-realigns on CursorHold (~4s idle) when table mode is
    -- active (table_mode_auto_align=1) — same buggy aligner. Kill it so even if
    -- table mode is ever enabled, idle time can't mangle a table.
    vim.g.table_mode_auto_align = 0
  end,
  config = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function()
        -- Do NOT call tablemode#Enable() — it maps | in insert mode to
        -- tableize and activates auto-alignment via CursorHold, which
        -- corrupts non-table lines that happen to contain |.

        local b = { buffer = true, silent = true }
        local bm = function(desc) return vim.tbl_extend("force", b, { desc = desc }) end

        -- ── Table: formula ──
        -- (Realign <Leader>tr is mapped further below, after safe_realign.)
        vim.keymap.set("n", "<Leader>tf", ":TableAddFormula<CR>", bm("Add formula"))
        vim.keymap.set("n", "<Leader>tF", ":TableEvalFormulaLine<CR>", bm("Eval formulas"))

        -- ── Table: sort ──
        vim.keymap.set("n", "<Leader>ts", ":TableSort<CR>", bm("Sort column asc"))
        vim.keymap.set("n", "<Leader>tS", ":TableSort!<CR>", bm("Sort column desc"))

        -- ── Table: delete ──
        vim.keymap.set("n", "<Leader>tdd", ":<C-U>call tablemode#spreadsheet#DeleteRow()<CR>", bm("Delete row"))
        vim.keymap.set("n", "<Leader>tdc", ":<C-U>call tablemode#spreadsheet#DeleteColumn()<CR>", bm("Delete column"))

        -- ── Table: insert ──
        vim.keymap.set("n", "<Leader>tic", ":<C-U>call tablemode#spreadsheet#InsertColumn(1)<CR>", bm("Insert col after"))
        vim.keymap.set("n", "<Leader>tiC", ":<C-U>call tablemode#spreadsheet#InsertColumn(0)<CR>", bm("Insert col before"))
        vim.keymap.set("n", "<Leader>tir", function()
          local lnum = vim.fn.line(".")
          local line = vim.fn.getline(lnum)
          -- Clear cell contents, keep pipe structure
          local empty = line:gsub("([^|]+)", function(cell)
            return string.rep(" ", #cell)
          end)
          vim.fn.append(lnum, empty)
          vim.fn.cursor(lnum + 1, 1)
          safe_realign()
          vim.fn.search("|\\s*\\zs\\S", "cW")
        end, vim.tbl_extend("force", b, { desc = "Insert row below" }))
        vim.keymap.set("n", "<Leader>tiR", function()
          local lnum = vim.fn.line(".")
          local line = vim.fn.getline(lnum)
          local empty = line:gsub("([^|]+)", function(cell)
            return string.rep(" ", #cell)
          end)
          vim.fn.append(lnum - 1, empty)
          vim.fn.cursor(lnum, 1)
          safe_realign()
          vim.fn.search("|\\s*\\zs\\S", "cW")
        end, vim.tbl_extend("force", b, { desc = "Insert row above" }))

        -- ── Table: navigate ──
        vim.keymap.set("n", "<Leader>tn", ":<C-U>call tablemode#spreadsheet#MoveToFirstRow()<CR>", bm("First row"))
        vim.keymap.set("n", "<Leader>tN", ":<C-U>call tablemode#spreadsheet#MoveToLastRow()<CR>", bm("Last row"))
        vim.keymap.set("n", "<Leader>t[", ":<C-U>call tablemode#spreadsheet#MoveToStartOfCell()<CR>", bm("Cell start"))
        vim.keymap.set("n", "<Leader>t]", ":<C-U>call tablemode#spreadsheet#MoveToEndOfCell()<CR>", bm("Cell end"))
        vim.keymap.set("n", "<Leader>te", ":<C-U>call tablemode#spreadsheet#EchoCell()<CR>", bm("Echo cell pos"))

        local function on_table_row()
          local line = vim.api.nvim_get_current_line()
          if line:sub(1, 1) ~= "|" then return false end
          local _, count = line:gsub("%|", "|")
          return count >= 2
        end

        -- Are we inside an existing table? Find the contiguous block of lines
        -- starting with `|` around the cursor and check whether it contains a
        -- separator row. The cursor's OWN line must be in the scan: when the
        -- cursor rests on the separator row (which happens naturally, since
        -- Tab from the header's last cell lands on `|---|`), scanning only the
        -- neighbors misses the separator and `create_table()` would fire,
        -- duplicating the separator and inserting a bogus empty row.
        local function in_existing_table()
          if not on_table_row() then return false end
          local lnum = vim.fn.line(".")
          local last = vim.fn.line("$")
          local top, bot = lnum, lnum
          while top > 1 and vim.fn.getline(top - 1):sub(1, 1) == "|" do top = top - 1 end
          while bot < last and vim.fn.getline(bot + 1):sub(1, 1) == "|" do bot = bot + 1 end
          for i = top, bot do
            if vim.fn.getline(i):find("^|[%s%-:]+|") then return true end
          end
          return false
        end

        -- Lenient header check for CREATION only: a line with ≥4 pipes that
        -- isn't already a |...| table row. Lets headers without a leading pipe
        -- (e.g. "score | name | ...") convert on Tab. The 4-pipe floor avoids
        -- misfiring on prose that merely contains a pipe — a bare "a | b" is
        -- left alone; use an explicit leading | (| a | b |) for short tables.
        -- Can't be inside a table here (on_table_row is false ⇒ no leading |).
        local function looks_like_header()
          local _, count = vim.api.nvim_get_current_line():gsub("%|", "|")
          return count >= 4
        end

        -- Decide what <Tab> does: "create" (start/extend a table), "next" (move
        -- to the next cell), or nil (fall through to the key default). Creation
        -- is lenient (looks_like_header); navigation stays strict (on_table_row
        -- ⇒ leading |) so Tab never misfires on prose mid-table.
        local function tab_target()
          if on_table_row() then
            return in_existing_table() and "next" or "create"
          elseif looks_like_header() then
            return "create"
          end
        end

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

        -- Display width of a string (multibyte-aware) — this is what makes a
        -- cell line up on screen. vim-table-mode's :TableModeRealign pads by
        -- byte length and is unreliable on long/unicode cells: it fails to
        -- expand header/separator rows and yields unequal row widths, so wide
        -- tables can't be normalized. We realign ourselves.
        -- NOTE: use nvim_strwidth, not strdisplaywidth() — the latter returns
        -- inconsistent values for long unicode strings in nvim 0.11.x (e.g. a
        -- 346-cell measures 359), which breaks uniform padding.
        local function cellwidth(s) return vim.api.nvim_strwidth(strip_concealed(s)) end

        -- Split a table row into trimmed cell contents, dropping the outer
        -- pipes. Handles rows with or without a leading/trailing pipe and
        -- preserves empty interior cells. Internal runs of whitespace are
        -- collapsed to a single space, which also self-heals cells the plugin's
        -- realign mangled (it pads with spaces inside a cell).
        local function parse_row(line)
          local s = line:gsub("^%s*|%s*", ""):gsub("%s*|%s*$", "")
          local cells = {}
          for c in vim.gsplit(s, "|", { plain = true, trimempty = false }) do
            cells[#cells + 1] = (c:gsub("^%s*(.-)%s*$", "%1"):gsub("%s+", " "))
          end
          return cells
        end

        -- Realign the contiguous block of `|` rows around the cursor so every
        -- column is padded to its widest cell (by display width) and every row
        -- ends up identical width. Separator rows (`---`/`:--:`/`---:`) are
        -- detected per column to preserve left/right/center alignment hints.
        local function realign_block(top, bot)
          -- Fit the table to WRAP_WIDTH (the window width): narrow columns pad
          -- to their widest cell so the pipes line up (the normal look), and if
          -- that would exceed the window the widest columns word-wrap into the
          -- column instead (Notion/org-mode style). A wrapped entry spans
          -- several physical rows with empty key cells on the continuation
          -- lines. render-markdown's pipe_table renderer (see
          -- render_markdown.lua) draws box-drawing borders over this fine, as
          -- long as column width accounts for concealed markup (see
          -- cellwidth()/strip_concealed() above) so its overlay and our raw
          -- text agree on width. Realign rejoins continuation rows before
          -- re-wrapping, so formatting is idempotent across saves.
          local WRAP_WIDTH = vim.g.table_realign_width
          if not WRAP_WIDTH then
            -- default: the window's actual text area. getwininfo().textoff is
            -- nvim's own count of the gutter (line numbers + sign column + fold
            -- column), so this fits the table precisely inside what's visible —
            -- no soft-wrapping the closing pipe past the edge. -1 leaves the
            -- closing pipe one cell inside the window; cap so an ultra-wide
            -- monitor doesn't make prose unreadably long.
            local wi = vim.fn.getwininfo(vim.fn.win_getid())[1]
            local textw = wi and (wi.width - wi.textoff) or vim.o.columns
            WRAP_WIDTH = math.max(40, math.min(textw - 1, 160))
          end

          -- Parse the block into header / separator / data rows, and rejoin
          -- hard-wrapped continuation rows (those whose first cell is empty)
          -- back into the logical row above, so re-wrapping starts clean.
          local header, sep_cells, align = {}, {}, {}
          local logical = {}
          for i = top, bot do
            local line = vim.fn.getline(i)
            if line:match("^%s*$") then
              -- stray blank line inside the block (table mode sometimes inserts
              -- these between rows); skip it — the table is regenerated without it
            else
              local cells = parse_row(line)
              local all_sep, has_dash = #cells > 0, false
              for _, c in ipairs(cells) do
                if not c:match("^[%-:%s]*$") then all_sep = false; break end
                if c:match("%-") then has_dash = true end
              end
              if all_sep and has_dash then
                sep_cells = cells
                for ci, c in ipairs(cells) do
                  local l, r = c:sub(1, 1) == ":", c:sub(-1) == ":"
                  align[ci] = (l and r) and "c" or (r and "r") or "l"
                end
              elseif #header == 0 and #logical == 0 then
                header = cells
              elseif cells[1] == "" and #logical > 0 then
                -- continuation row: fold its cells into the previous logical row
                local prev = logical[#logical]
                for ci = 2, #cells do
                  local add = cells[ci] or ""
                  if add ~= "" then
                    prev.cells[ci] = (prev.cells[ci] == "" and add or prev.cells[ci] .. " " .. add)
                  end
                end
              else
                logical[#logical + 1] = { cells = cells }
              end
            end
          end

          local ncols = 0
          for _, row in ipairs(logical) do ncols = math.max(ncols, #row.cells) end
          ncols = math.max(ncols, #header, #sep_cells)

          -- Widest cell per column across header + (rejoined) data rows.
          local maxw = {}
          local function track(ci, c)
            if c then maxw[ci] = math.max(maxw[ci] or 1, cellwidth(c)) end
          end
          for ci = 1, ncols do track(ci, header[ci]) end
          for _, row in ipairs(logical) do
            for ci = 1, #row.cells do track(ci, row.cells[ci]) end
          end

          -- Decide which columns wrap so the table fits WRAP_WIDTH. Narrow
          -- columns keep their full width (pipes align); the widest columns
          -- wrap (prose) and share the width left over. A table that already
          -- fits the window wraps nothing. wrap[ci] is a boolean; colw[ci] is
          -- the column's render width either way.
          -- Concealed markup (backticks, **bold**, etc.) adds raw characters
          -- that vanish on render but still count toward the buffer's actual
          -- physical line length — Neovim's line-wrap operates on that raw
          -- length, not the rendered one. Budget for the worst-case row's
          -- concealed overhead so a table with e.g. backtick-wrapped cells
          -- doesn't overflow the window by those invisible chars and get its
          -- trailing pipe raggedly soft-wrapped onto its own line.
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
          local GRACE = vim.g.table_realign_grace or 0
          local overhead = 3 * ncols + 1 + max_overhead  -- pipes/padding + worst-case concealed-markup slack
          local avail = WRAP_WIDTH - overhead
          local order = {}
          for ci = 1, ncols do order[ci] = ci end
          table.sort(order, function(a, b) return (maxw[a] or 0) < (maxw[b] or 0) end)
          local fullw_total = 0
          for ci = 1, ncols do fullw_total = fullw_total + (maxw[ci] or 0) end
          local wrap, n_wrap = {}, 0
          -- Wrap whenever the table would exceed the window (default GRACE=0):
          -- a table wider than the screen soft-wraps into an unreadable mess,
          -- so we wrap its widest columns to fit instead. GRACE>0 lets tables
          -- overflow by that many columns before wrapping (set
          -- vim.g.table_realign_grace if you'd rather scroll than wrap).
          if fullw_total + overhead > WRAP_WIDTH + GRACE then
            for idx = #order, 1, -1 do  -- widest first: shed columns into wrap until it fits
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

          emit(header)
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
            local lines_per, height = {}, 1
            for ci = 1, ncols do
              local c = row.cells[ci] or ""
              lines_per[ci] = wrap[ci] and wordwrap(c, colw[ci]) or { c }
              if #lines_per[ci] > height then height = #lines_per[ci] end
            end
            for li = 1, height do
              local cells = {}
              for ci = 1, ncols do
                cells[ci] = (li == 1) and (lines_per[ci][1] or "") or (lines_per[ci][li] or "")
              end
              emit(cells)
            end
          end
          -- nvim_buf_set_lines (not setline): the row count changes when a
          -- prose column wraps, so the replaced range must be exact.
          vim.api.nvim_buf_set_lines(0, top - 1, bot, false, out)
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
        -- bottom-up: realigning a block changes line counts, so blocks at
        -- higher line numbers go first and don't shift the offsets of the rest.
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
              -- next |-run (across blank lines) has no separator of its own,
              -- it's a continuation of THIS table — fold it in so realign
              -- regenerates the table as one block (dropping the blank line). A
              -- genuine second table carries its own separator and is left alone.
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

        -- Realign — uses the custom aligner above (correct for long/unicode
        -- cells), not the plugin's :TableModeRealign.
        vim.keymap.set("n", "<Leader>tr", safe_realign, bm("Realign"))
        -- Expose safe_realign to VimL so we can redirect the plugin's function.
        _G.__table_realign = safe_realign
        -- Neutralize the plugin's realign completely. Every caller — the
        -- :TableModeRealign command, the CursorHold idle auto-align, cell
        -- motions, tableize — funnels through tablemode#table#Realign, which
        -- mangles wide/unicode tables (spaces inside cells/separators). We
        -- force the plugin's autoload to load, then replace that ONE function
        -- with ours, so the mangling realign can never run from any path.
        local function hijack_realign()
          pcall(vim.api.nvim_del_user_command, "TableModeRealign")
          pcall(vim.api.nvim_create_user_command, "TableModeRealign", safe_realign, {})
          pcall(vim.cmd, "runtime autoload/tablemode/table.vim")
          pcall(vim.cmd, [[function! tablemode#table#Realign(...) abort range
            silent! call luaeval('_G.__table_realign()')
          endfunction]])
        end
        hijack_realign()

        -- ── Table: swap columns ──
        local function swap_col(dir)
          if not in_existing_table() then return end
          local lnum = vim.fn.line(".")
          local line = vim.fn.getline(lnum)
          local before = line:sub(1, vim.fn.col(".") - 1)
          local _, pipes = before:gsub("%|", "|")
          local col = pipes
          if col < 1 then return end
          local target = col + dir
          if target < 1 then return end

          local top, bot = lnum, lnum
          while top > 1 and vim.fn.getline(top - 1):sub(1, 1) == "|" do top = top - 1 end
          while vim.fn.getline(bot + 1):sub(1, 1) == "|" do bot = bot + 1 end

          for i = top, bot do
            local row = vim.fn.getline(i)
            local trimmed = row:gsub("|%s*$", "")
            local parts = vim.split(trimmed, "|")
            if #parts > target then
              parts[col + 1], parts[target + 1] = parts[target + 1], parts[col + 1]
              vim.fn.setline(i, table.concat(parts, "|") .. "|")
            end
          end
          safe_realign()
        end

        vim.keymap.set("n", "<Leader>t>", function() swap_col(1) end, bm("Move col right"))
        vim.keymap.set("n", "<Leader>t<", function() swap_col(-1) end, bm("Move col left"))

        -- Parse a header line into cells: {text, width}
        local function parse_cells(line)
          line = line:gsub("%s*$", ""):gsub("|%s*$", "")
          -- Allow headers without a leading pipe (e.g. "score | name | ..."):
          -- the gmatch below keys off a leading |, so synthesize one when
          -- absent, otherwise the first cell ("score") is silently dropped.
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
          vim.fn.search("|\\s*\\zs\\S", "cW")
        end

        local function next_cell()
          if not in_existing_table() then return false end
          safe_realign()
          vim.fn.search("|\\s*\\zs\\S", "W")
          return true
        end

        local function prev_cell()
          if not in_existing_table() then return false end
          safe_realign()
          vim.fn.search("\\S\\ze\\s*|", "bW")
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

        -- Auto-realign tables on save — only when cursor is inside a proper table
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = 0,
          desc = "Realign markdown tables before save",
          callback = realign_all_tables,
        })

        -- Also realign once on open, so a table typed/pasted elsewhere (e.g. by
        -- an LLM, or before this plugin existed) renders correctly immediately
        -- instead of looking broken until the first <Leader>tr or save. This is
        -- purely cosmetic materialization of already-saved content, so clear
        -- 'modified' after — it must not force a save prompt on a file the user
        -- never actually touched.
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(0) then return end
          realign_all_tables()
          vim.bo[0].modified = false
        end)
      end,
    })
  end,
}
