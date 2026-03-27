-- Configure which-key hints and the global key hint entrypoint.
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    delay = 150,
    notify = false,
    -- Don't trigger in operator-pending mode (breaks flash remote)
    triggers = { "<leader>" },
    spec = {
      { "<leader>x", desc = "Close buffer" },
      { "<C-j>", desc = "Scroll — half page down" },
      { "<C-k>", desc = "Scroll — half page up" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = true })
      end,
      desc = "Show key hints",
    },
  },
}
