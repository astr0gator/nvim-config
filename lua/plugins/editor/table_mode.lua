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

        -- Tab / Shift-Tab: next/prev cell (only on table lines)
        vim.keymap.set("n", "<Tab>", function()
          if vim.api.nvim_get_current_line():find("|") then
            vim.cmd("TableModeRealign")
            vim.fn.search("|", "W")
          end
        end, vim.tbl_extend("force", b, { desc = "Table: next cell" }))

        vim.keymap.set("n", "<S-Tab>", function()
          if vim.api.nvim_get_current_line():find("|") then
            vim.cmd("TableModeRealign")
            vim.fn.search("|", "bW")
          end
        end, vim.tbl_extend("force", b, { desc = "Table: prev cell" }))

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
