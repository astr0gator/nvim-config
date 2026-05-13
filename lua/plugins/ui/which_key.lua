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

      -- ── Theme ──
      { "<leader>o",  group = "options", icon = " " },
      { "<leader>ot", desc = "Theme — Flexoki" },
      { "<leader>ot", desc = "Theme — Tokyonight" },
      { "<leader>om", desc = "Theme — Miasma" },
      { "<leader>on", desc = "Theme — next" },
      { "<leader>op", desc = "Theme — previous" },
      { "<leader>oa", desc = "Autosave toggle" },

      -- ── Palette ──
      { "<leader>p",  group = "palette", icon = " " },

      -- ── Markdown tables ──
      { "<leader>m",  group = "table",   icon = " " },

      -- ── Misc ──
      { "<leader>?",  desc = "Key hints" },

      -- ── Non-leader: Scroll ──
      { "<C-j>", desc = "Scroll down" },
      { "<C-k>", desc = "Scroll up" },

      -- ── Non-leader: Tabs ──
      { "gt",    desc = "Next tab" },
      { "gT",    desc = "Previous tab" },

      -- ── Non-leader: Navigation ──
      { "gh",    desc = "Line start (non-blank)" },
      { "gl",    desc = "Line end" },
      { "s",     desc = "Flash — jump to char" },
      { "S",     desc = "Flash — treesitter jump" },
      { "-",     desc = "Focus file tree" },

      -- ── Non-leader: Buffer ──
      { "<S-h>", desc = "Previous buffer" },
      { "<S-l>", desc = "Next buffer" },

      -- ── Non-leader: LSP ──
      { "gd",    desc = "Go to definition" },
      { "gD",    desc = "Go to declaration" },
      { "gr",    desc = "Show references" },
      { "K",     desc = "Hover docs" },

      -- ── Non-leader: Fold ──
      { "za",    desc = "Fold — toggle" },
      { "zM",    desc = "Fold — close all" },
      { "zR",    desc = "Fold — open all" },

      -- ── Non-leader: Multi-cursor ──
      { "<C-n>", desc = "Multi-cursor — select word" },

      -- ── Non-leader: Misc ──
      { "U",     desc = "Redo" },
      { "<C-a>", desc = "Select all" },
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
