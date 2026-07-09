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

-- <CR> in markdown: continue a checkbox/list, toggle a fold under the cursor,
-- or move down a line. Extracted to a named _G function (mirroring
-- _G.markdown_foldexpr above) so the behaviour is unit-tested in
-- tests/markdown_fold_mappings.lua. List items win over folding because a `##`
-- heading makes every line beneath it foldable — checking foldlevel first would
-- make Enter fold (not continue the list) for a list item under a heading.
_G.markdown_enter = function()
  local line = vim.api.nvim_get_current_line()
  -- Checkbox lines match the bullet pattern too, but must continue as `- [ ]`
  -- (not a plain `- `), so handle them before the bullet branch.
  if _G.markdown_is_checkbox and _G.markdown_is_checkbox(line) then
    _G.markdown_continue_checkbox()
    return
  end
  if line:match("^%s*[%-%*%+]%s") or line:match("^%s*%d+[%.%)]%s") then
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<Plug>(bullets-newline)", true, true, true), "m", false)
    return
  end
  if vim.fn.foldlevel(".") > 0 then
    vim.cmd("normal! za")
    return
  end
  -- Down one line to the first non-blank (the <CR> motion), run synchronously
  -- so it is deterministic to test (feedkeys would only queue it async).
  vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<CR>", true, false, true))
end

-- <C-CR> in markdown: if any fold is closed, open all (zR); otherwise close
-- all (zM). Returns the keys to run (used as an expr mapping).
_G.markdown_toggle_all_folds = function()
  for i = 1, vim.fn.line("$") do
    if vim.fn.foldclosed(i) ~= -1 then
      return "zR"
    end
  end
  return "zM"
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
    vim.opt_local.foldlevel = 99

    -- First time: all folds open (foldlevel=99). On revisit: restore saved folds.
    vim.schedule(function()
      vim.cmd("silent! loadview")
    end)

    -- Save fold state when leaving the window
    vim.api.nvim_create_autocmd("BufWinLeave", {
      buffer = 0,
      callback = function()
        vim.cmd("silent! mkview")
      end,
    })

    -- Restore fold state when switching back to this buffer
    vim.api.nvim_create_autocmd("BufWinEnter", {
      buffer = 0,
      callback = function()
        vim.schedule(function()
          vim.cmd("silent! loadview")
        end)
      end,
    })

    local bopts = { buffer = true, noremap = true, silent = true }

    -- <CR>/<C-CR> delegate to the tested _G helpers defined above.
    vim.keymap.set("n", "<CR>", _G.markdown_enter,
      vim.tbl_extend("force", bopts, { desc = "List — add item / toggle fold / line down" }))

    -- Ctrl+Enter: toggle all folds in buffer
    vim.keymap.set("n", "<C-CR>", _G.markdown_toggle_all_folds,
      vim.tbl_extend("force", bopts, { expr = true, desc = "Fold — toggle all in buffer" }))

    -- gO: fuzzy, j/k-navigable table-of-contents (telescope). Overrides the
    -- built-in gO (vim.lsp.buf.document_symbol), which is flat + fuzzy-less and
    -- usually empty for markdown. See config/markdown_toc.lua.
    vim.keymap.set("n", "gO", function() require("config.markdown_toc").pick() end,
      vim.tbl_extend("force", bopts, { desc = "TOC (markdown)" }))
  end,
})

vim.opt.viewoptions = { "cursor", "curdir", "folds" }

-- Set cursor color and dim line numbers after colorscheme changes
autocmd("ColorScheme", {
  desc = "Apply custom cursor color and dimmed line numbers",
  callback = function()
    local theme = require("config.theme")
    theme.set_cursor()
    theme.set_line_numbers()
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
