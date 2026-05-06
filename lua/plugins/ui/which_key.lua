-- Configure which-key hints and the global key hint entrypoint.
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    delay = 150,
    notify = false,
    triggers = {
      { "<auto>", mode = "nixstc" },
    },
    spec = {
      -- ── File ──
      { "<leader>w",  desc = "Save" },
      { "<leader>Z",  desc = "Save all" },
      { "<leader>q",  desc = "Save + quit" },
      { "<leader>Q",  desc = "Force quit" },
      { "<leader>x",  desc = "Close buffer" },

      -- ── Find / Navigate ──
      { "<leader>f",  desc = "Find files" },
      { "<leader>b",  desc = "Buffers" },
      { "<leader>/",  desc = "Grep" },
      { "<leader>h",  desc = "Help" },
      { "<leader>k",  desc = "Keymaps" },
      { "<leader>e",  desc = "File tree" },
      { "<leader>;",  desc = "Command mode" },

      -- ── Palette ──
      { "<leader>p",  group = "palette", icon = " " },

      -- ── Options ──
      { "<leader>o",  group = "options", icon = " " },

      -- ── Markdown tables ──
      { "<leader>m",  group = "table",   icon = " " },

      -- ── Misc ──
      { "<leader>?",  desc = "Key hints" },

      -- ── Non-leader ──
      { "<C-j>", desc = "Scroll down" },
      { "<C-k>", desc = "Scroll up" },
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
