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

        -- ── Table: realign / formula ──
        vim.keymap.set("n", "<Leader>mr", ":TableModeRealign<CR>", bm("Realign"))
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

        -- Are we inside an existing table? Scan the full table extent for a separator row.
        local function in_existing_table()
          if not on_table_row() then return false end
          local lnum = vim.fn.line(".")
          local last = vim.fn.line("$")
          for dir = -1, 1, 2 do
            local i = lnum + dir
            while i >= 1 and i <= last do
              local line = vim.fn.getline(i)
              if line:sub(1, 1) ~= "|" then break end
              if line:find("^|[%s%-:]+|") then return true end
              i = i + dir
            end
          end
          return false
        end

        -- Safe realign: only realign lines within a proper table boundary
        -- (delimited by separator rows). Does NOT touch lines that merely
        -- contain | but aren't part of a real table.
        local function safe_realign()
          if not in_existing_table() then return end
          pcall(vim.cmd, "TableModeRealign")
        end

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
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true), "n", false)
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
          callback = function()
            if in_existing_table() then
              pcall(vim.cmd, "TableModeRealign")
            end
          end,
        })
      end,
    })
  end,
}
