-- Register core autocmds and wire up local automation modules.
local autocmd = vim.api.nvim_create_autocmd

require("config.automation.autosave").setup()
require("config.automation.task_ids").setup()

autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  callback = function()
    vim.highlight.on_yank()
  end,
})

_G.markdown_foldtext = function()
  local line = vim.fn.trim(vim.fn.getline(vim.v.foldstart))
  local count = vim.v.foldend - vim.v.foldstart + 1
  return string.format("%s [%d lines]", line, count)
end

_G.markdown_foldexpr = function()
  local level = vim.fn.getline(vim.v.lnum):match("^(#+)%s")
  if level then
    return ">" .. math.min(#level, 6)
  end
  return "="
end

autocmd("FileType", {
  pattern = "markdown",
  desc = "Configure markdown: visual wrapping, heading-based folding, fold keymaps",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.markdown_foldexpr()"
    vim.opt_local.foldtext = "v:lua.markdown_foldtext()"
    vim.opt_local.foldlevelstart = 99

    local bopts = { buffer = true, noremap = true, silent = true }

    -- Enter: toggle fold under cursor
    vim.keymap.set("n", "<CR>", function()
      if vim.fn.foldlevel(".") > 0 then
        return "za"
      end
      return "<CR>"
    end, vim.tbl_extend("force", bopts, { expr = true, desc = "Fold — toggle under cursor" }))

    -- Ctrl+Enter: toggle all folds in buffer
    vim.keymap.set("n", "<C-CR>", function()
      for i = 1, vim.fn.line("$") do
        if vim.fn.foldclosed(i) ~= -1 then
          return "zR"
        end
      end
      return "zM"
    end, vim.tbl_extend("force", bopts, { expr = true, desc = "Fold — toggle all in buffer" }))
  end,
})

-- Save and restore cursor position only (no fold persistence)
vim.opt.viewoptions = { "cursor", "curdir" }

-- Set cursor color after colorscheme changes
autocmd("ColorScheme", {
  desc = "Apply custom cursor color",
  callback = function()
    local theme = require("config.theme")
    theme.set_cursor()
  end,
})

-- Reload config command
local function reload_config()
  package.loaded['config.keymaps'] = nil
  package.loaded['config.autocmds'] = nil
  require("config.keymaps")
  require("config.autocmds")
  vim.notify("Config reloaded!", vim.log.levels.INFO)
end
vim.api.nvim_create_user_command("Rel", reload_config, { desc = "Reload config" })
vim.cmd.cabbrev("rel Rel")

autocmd("InsertEnter", {
  callback = function()
    vim.opt.cursorline = true
    vim.schedule(function()
      local bg = vim.o.background == "dark" and "#333345" or "#f0f0f0"
      vim.api.nvim_set_hl(0, "CursorLine", { bg = bg })
    end)
  end,
})

autocmd("InsertLeave", {
  callback = function()
    vim.opt.cursorline = false
  end,
})
