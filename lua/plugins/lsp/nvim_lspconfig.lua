-- Configure built-in LSP clients, diagnostics, and LSP keymaps.
return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    vim.diagnostic.config({
      severity_sort = true,
      float = { border = "rounded" },
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(event)
        local map = vim.keymap.set
        local opts = { buffer = event.buf, silent = true }

        map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
        map("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Go to references" }))
        map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover docs" }))
        map("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename symbol" }))
        -- Code action on gK (next to gd/gr/K); freed <leader>c for the TOC.
        map("n", "gK", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
      end,
    })

    local servers = {
      lua_ls = {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
          },
        },
      },
      html = {},
      cssls = {},
    }

    for server, config in pairs(servers) do
      vim.lsp.config(server, config)
      vim.lsp.enable(server)
    end
  end,
}
