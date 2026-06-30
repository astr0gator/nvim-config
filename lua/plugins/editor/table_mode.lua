-- Configure markdown table editing helpers via vim-table-mode.
return {
  "dhruvasagar/vim-table-mode",
  ft = "markdown",
  init = function()
    vim.g.table_mode_corner = "|"
    vim.g.table_mode_align_char = ":"
    -- Do NOT set table_mode_always_active — vim-table-mode treats ANY line
    -- starting with | as a table row and will corrupt non-table content.
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
        -- (Realign <Leader>mr is mapped further below, after safe_realign.)
        vim.keymap.set("n", "<Leader>mf", ":TableAddFormula<CR>", bm("Add formula"))
        vim.keymap.set("n", "<Leader>mF", ":TableEvalFormulaLine<CR>", bm("Eval formulas"))

        -- ── Table: sort ──
        vim.keymap.set("n", "<Leader>ms", ":TableSort<CR>", bm("Sort column asc"))
        vim.keymap.set("n", "<Leader>mS", ":TableSort!<CR>", bm("Sort column desc"))

        -- ── Table: delete ──
        vim.keymap.set("n", "<Leader>mdd", ":<C-U>call tablemode#spreadsheet#DeleteRow()<CR>", bm("Delete row"))
        vim.keymap.set("n", "<Leader>mdc", ":<C-U>call tablemode#spreadsheet#DeleteColumn()<CR>", bm("Delete column"))

        -- ── Table: insert ──
        vim.keymap.set("n", "<Leader>mic", ":<C-U>call tablemode#spreadsheet#InsertColumn(1)<CR>", bm("Insert col after"))
        vim.keymap.set("n", "<Leader>miC", ":<C-U>call tablemode#spreadsheet#InsertColumn(0)<CR>", bm("Insert col before"))
        vim.keymap.set("n", "<Leader>mir", function()
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
        vim.keymap.set("n", "<Leader>miR", function()
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
        vim.keymap.set("n", "<Leader>mn", ":<C-U>call tablemode#spreadsheet#MoveToFirstRow()<CR>", bm("First row"))
        vim.keymap.set("n", "<Leader>mN", ":<C-U>call tablemode#spreadsheet#MoveToLastRow()<CR>", bm("Last row"))
        vim.keymap.set("n", "<Leader>m[", ":<C-U>call tablemode#spreadsheet#MoveToStartOfCell()<CR>", bm("Cell start"))
        vim.keymap.set("n", "<Leader>m]", ":<C-U>call tablemode#spreadsheet#MoveToEndOfCell()<CR>", bm("Cell end"))
        vim.keymap.set("n", "<Leader>me", ":<C-U>call tablemode#spreadsheet#EchoCell()<CR>", bm("Echo cell pos"))

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

        -- Display width of a string (multibyte-aware) — this is what makes a
        -- cell line up on screen. vim-table-mode's :TableModeRealign pads by
        -- byte length and is unreliable on long/unicode cells: it fails to
        -- expand header/separator rows and yields unequal row widths, so wide
        -- tables can't be normalized. We realign ourselves.
        -- NOTE: use nvim_strwidth, not strdisplaywidth() — the latter returns
        -- inconsistent values for long unicode strings in nvim 0.11.x (e.g. a
        -- 346-cell measures 359), which breaks uniform padding.
        local function cellwidth(s) return vim.api.nvim_strwidth(s) end

        -- Split a table row into trimmed cell contents, dropping the outer
        -- pipes. Handles rows with or without a leading/trailing pipe and
        -- preserves empty interior cells.
        local function parse_row(line)
          local s = line:gsub("^%s*|%s*", ""):gsub("%s*|%s*$", "")
          local cells = {}
          for c in vim.gsplit(s, "|", { plain = true, trimempty = false }) do
            cells[#cells + 1] = (c:gsub("^%s*(.-)%s*$", "%1"))
          end
          return cells
        end

        -- Realign the contiguous block of `|` rows around the cursor so every
        -- column is padded to its widest cell (by display width) and every row
        -- ends up identical width. Separator rows (`---`/`:--:`/`---:`) are
        -- detected per column to preserve left/right/center alignment hints.
        local function realign_table()
          -- Columns wider than this stay ragged (each cell at its natural
          -- width) so a single paragraph-length cell can't pad the whole
          -- table out to hundreds of columns. Narrow columns still align.
          local MAX_COL_WIDTH = 40
          local lnum = vim.fn.line(".")
          local last = vim.fn.line("$")
          local top, bot = lnum, lnum
          while top > 1 and vim.fn.getline(top - 1):sub(1, 1) == "|" do top = top - 1 end
          while bot < last and vim.fn.getline(bot + 1):sub(1, 1) == "|" do bot = bot + 1 end

          local rows, maxw, align = {}, {}, {}
          for i = top, bot do
            local cells = parse_row(vim.fn.getline(i))
            local all_sep, has_dash = #cells > 0, false
            for _, c in ipairs(cells) do
              if not c:match("^[%-:%s]*$") then all_sep = false; break end
              if c:match("%-") then has_dash = true end
            end
            local is_sep = all_sep and has_dash
            rows[#rows + 1] = { cells = cells, sep = is_sep }
            if is_sep then
              for ci, c in ipairs(cells) do
                local l, r = c:sub(1, 1) == ":", c:sub(-1) == ":"
                align[ci] = (l and r) and "c" or (r and "r") or "l"
              end
            else
              for ci, c in ipairs(cells) do
                maxw[ci] = math.max(maxw[ci] or 1, cellwidth(c))
              end
            end
          end

          -- Column count = widest row. Ragged rows (e.g. a separator missing a
          -- column, a common copy-paste malformation) are padded out so the
          -- separator is regenerated with the right number of dash columns.
          local ncols = 0
          for _, row in ipairs(rows) do ncols = math.max(ncols, #row.cells) end

          local out = {}
          for ri, row in ipairs(rows) do
            local parts = {}
            for ci = 1, ncols do
              local c = row.cells[ci] or ""
              local w = math.min(maxw[ci] or cellwidth(c), MAX_COL_WIDTH)
              if row.sep then
                if align[ci] == "c" then parts[ci] = ":" .. string.rep("-", w) .. ":"
                elseif align[ci] == "r" then parts[ci] = string.rep("-", w + 1) .. ":"
                elseif align[ci] == "l" and c:sub(1, 1) == ":" then parts[ci] = ":" .. string.rep("-", w + 1)
                else parts[ci] = string.rep("-", w + 2) end
              else
                local pad = string.rep(" ", math.max(0, w - cellwidth(c)))
                parts[ci] = " " .. (align[ci] == "r" and (pad .. c) or (c .. pad)) .. " "
              end
            end
            out[ri] = "|" .. table.concat(parts, "|") .. "|"
          end
          vim.fn.setline(top, out)
        end

        -- Safe realign: only when the cursor sits inside a proper table (a
        -- `|`-block containing a separator row). Never touches lines that
        -- merely contain `|` but aren't a real table.
        local function safe_realign()
          if not in_existing_table() then return end
          realign_table()
        end

        -- Realign — uses the custom aligner above (correct for long/unicode
        -- cells), not the plugin's :TableModeRealign.
        vim.keymap.set("n", "<Leader>mr", safe_realign, bm("Realign"))

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

        vim.keymap.set("n", "<Leader>m>", function() swap_col(1) end, bm("Move col right"))
        vim.keymap.set("n", "<Leader>m<", function() swap_col(-1) end, bm("Move col left"))

        -- Parse a header line into cells: {text, width}
        local function parse_cells(line)
          line = line:gsub("%s*$", ""):gsub("|%s*$", "")
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
          if not on_table_row() then
            vim.api.nvim_feedkeys("\22", "n", false)
            return
          end
          if not in_existing_table() then create_table() else next_cell() end
        end, vim.tbl_extend("force", b, { desc = "Table: next cell" }))

        vim.keymap.set("i", "<Tab>", function()
          if not on_table_row() then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
            return
          end
          vim.schedule(function()
            vim.cmd("stopinsert")
            if not in_existing_table() then create_table() else next_cell() end
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
          callback = function() safe_realign() end,
        })
      end,
    })
  end,
}
