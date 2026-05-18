-- Configure flash.nvim motions and search toggles.
local labels = "asdfghjklqwertyuiopzxcvbnm"

local function jump_to(match, state, pos)
  local jump = require("flash.jump")
  local original_pos = state.opts.jump.pos

  state.opts.jump.pos = pos
  jump.jump(match, state)
  jump.on_jump(state)
  state.opts.jump.pos = original_pos
end

local function end_label_actions()
  local actions = {}

  for label in labels:gmatch(".") do
    local upper = label:upper()
    if upper ~= label then
      actions[upper] = function(state)
        local match = state:find({ label = label })
        if match then
          jump_to(match, state, "end")
          state:hide()
          return false
        end
      end
    end
  end

  return actions
end

return {
  "folke/flash.nvim",
  event = "VeryLazy",
  ---@type Flash.Config
  opts = {
    labels = labels,
    actions = end_label_actions(),
    label = { uppercase = false },
    modes = { search = { enabled = true } },
    highlight = {
      groups = {
        match = "FlashMatch",
        label = "FlashLabel",
        current = "FlashCurrent",
        backdrop = "FlashBackdrop",
      },
    },
  },
  config = function(_, opts)
    require("flash").setup(opts)

    local function set_flash_highlights()
      local cursor_color = require("config.theme").cursor_color
      vim.api.nvim_set_hl(0, "FlashMatch", { fg = "#ffffff", bg = "#656565" })
      vim.api.nvim_set_hl(0, "FlashLabel", { fg = "#ffffff", bg = cursor_color, bold = true })
      vim.api.nvim_set_hl(0, "FlashCurrent", { fg = "#ffffff", bg = "#757575" })
      vim.api.nvim_set_hl(0, "FlashBackdrop", { fg = "#5c5c5c" })
      -- Restore cursor color in case colorscheme cleared it
      vim.api.nvim_set_hl(0, "Cursor", { bg = cursor_color })
      vim.api.nvim_set_hl(0, "lCursor", { bg = cursor_color })
      vim.api.nvim_set_hl(0, "CursorIM", { bg = cursor_color })
      vim.api.nvim_set_hl(0, "TermCursor", { bg = cursor_color })
    end

    set_flash_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = vim.schedule_wrap(set_flash_highlights) })
  end,
  keys = {
    { ";", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
}
