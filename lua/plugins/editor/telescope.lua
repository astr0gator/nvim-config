-- Configure Telescope pickers and the main search keybindings.
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  keys = {
    { "<leader>pp", "<cmd>Telescope commands<CR>", desc = "Command palette" },
    { "<leader>f", "<cmd>Telescope find_files<CR>", desc = "Telescope — find files" },
    { "<leader>/", "<cmd>Telescope live_grep<CR>", desc = "Telescope — grep in files" },
    { "<leader>b", "<cmd>Telescope buffers<CR>", desc = "Telescope — open buffers" },
    { "<leader>h", "<cmd>Telescope help_tags<CR>", desc = "Telescope — help pages" },
    { "<leader>k", "<cmd>Telescope keymaps<CR>", desc = "Telescope — keymaps" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      sorting_strategy = "ascending",
      mappings = {
        i = {
          ["<leader>q"] = "close",
        },
        n = {
          ["<leader>q"] = "close",
        },
      },
      file_ignore_patterns = nil,
    },
    pickers = {
      find_files = {
        find_command = { "fd", "--type", "f", "--hidden", "--no-ignore", "--strip-cwd-prefix" },
      },
    },
  },
}
