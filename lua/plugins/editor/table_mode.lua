-- Configure markdown table editing helpers via vim-table-mode.
return {
  "dhruvasagar/vim-table-mode",
  ft = "markdown",
  init = function()
    vim.g.table_mode_corner = "|"
    vim.g.table_mode_align_char = ":"
    vim.g.table_mode_always_active = 1
  end,
  config = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function()
        vim.cmd("call tablemode#Enable()")

        local b = { buffer = true, silent = true }

        vim.keymap.set("n", "<Leader>mr", ":TableModeRealign<CR>", vim.tbl_extend("force", b, { desc = "Table: realign all" }))
        vim.keymap.set("n", "<Leader>mdd", ":<C-U>call tablemode#spreadsheet#DeleteRow()<CR>", vim.tbl_extend("force", b, { desc = "Table: delete row" }))
        vim.keymap.set("n", "<Leader>mdc", ":<C-U>call tablemode#spreadsheet#DeleteColumn()<CR>", vim.tbl_extend("force", b, { desc = "Table: delete column" }))
        vim.keymap.set("n", "<Leader>miC", ":<C-U>call tablemode#spreadsheet#InsertColumn(0)<CR>", vim.tbl_extend("force", b, { desc = "Table: insert col before" }))
        vim.keymap.set("n", "<Leader>mic", ":<C-U>call tablemode#spreadsheet#InsertColumn(1)<CR>", vim.tbl_extend("force", b, { desc = "Table: insert col after" }))
        vim.keymap.set("n", "<Leader>mir", function()
          local lnum = vim.fn.line(".")
          local line = vim.fn.getline(lnum)
          -- Clear cell contents, keep pipe structure
          local empty = line:gsub("([^|]+)", function(cell)
            return string.rep(" ", #cell)
          end)
          vim.fn.append(lnum, empty)
          vim.fn.cursor(lnum + 1, 1)
          vim.cmd("TableModeRealign")
          vim.fn.search("|\\s*\\zs\\S", "cW")
        end, vim.tbl_extend("force", b, { desc = "Table: insert row below" }))
        vim.keymap.set("n", "<Leader>miR", function()
          local lnum = vim.fn.line(".")
          local line = vim.fn.getline(lnum)
          local empty = line:gsub("([^|]+)", function(cell)
            return string.rep(" ", #cell)
          end)
          vim.fn.append(lnum - 1, empty)
          vim.fn.cursor(lnum, 1)
          vim.cmd("TableModeRealign")
          vim.fn.search("|\\s*\\zs\\S", "cW")
        end, vim.tbl_extend("force", b, { desc = "Table: insert row above" }))

        local function on_table_row()
          return vim.api.nvim_get_current_line():find("|") ~= nil
        end

        -- Are we inside an existing table? Check for separator row above or below.
        local function in_existing_table()
          if not on_table_row() then return false end
          local lnum = vim.fn.line(".")
          local below = vim.fn.getline(lnum + 1)
          local above = vim.fn.getline(lnum - 1)
          if below:find("^|[%s%-:]+|") or above:find("^|[%s%-:]+|") then
            return true
          end
          -- Also check 2 lines above (we might be on the separator itself)
          local above2 = vim.fn.getline(lnum - 2)
          if above2:find("^|[%s%-:]+|") then return true end
          return false
        end

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
          pcall(vim.cmd, "TableModeRealign")
          vim.fn.cursor(lnum + 2, 1)
          vim.fn.search("|\\s*\\zs\\S", "cW")
        end

        local function next_cell()
          if not on_table_row() then return false end
          pcall(vim.cmd, "TableModeRealign")
          vim.fn.search("|\\s*\\zs\\S", "W")
          return true
        end

        local function prev_cell()
          if not on_table_row() then return false end
          pcall(vim.cmd, "TableModeRealign")
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

        -- Auto-realign tables on save
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = 0,
          desc = "Realign markdown tables before save",
          callback = function()
            if vim.fn.search("|", "nw") > 0 then
              vim.cmd("TableModeRealign")
            end
          end,
        })
      end,
    })
  end,
}
