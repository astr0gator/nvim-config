-- Auto-save file buffers when Neovim loses focus.
local M = {}

local autocmd_id = nil

function M.setup()
  autocmd_id = vim.api.nvim_create_autocmd("FocusLost", {
    callback = function()
      if not M.enabled then
        return
      end
      -- Skip non-file buffers (telescope, neo-tree, help, etc.)
      if vim.bo.buftype ~= "" then
        return
      end
      if vim.bo.modified and not vim.bo.readonly then
        vim.cmd("silent write")
      end
    end,
    desc = "Auto-save on focus lost",
  })
  M.enabled = true
end

function M.toggle()
  M.enabled = not M.enabled
  local state = M.enabled and "on" or "off"
  vim.notify("Autosave on focus lost: " .. state, vim.log.levels.INFO)
end

return M
