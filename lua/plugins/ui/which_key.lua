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
      { "<leader>mr", desc = "Realign" },
      { "<leader>mf", desc = "Add formula" },
      { "<leader>mF", desc = "Eval formulas" },
      { "<leader>ms", desc = "Sort column asc" },
      { "<leader>mS", desc = "Sort column desc" },
      { "<leader>mdd", desc = "Delete row" },
      { "<leader>mdc", desc = "Delete column" },
      { "<leader>mic", desc = "Insert col after" },
      { "<leader>miC", desc = "Insert col before" },
      { "<leader>mir", desc = "Insert row below" },
      { "<leader>miR", desc = "Insert row above" },
      { "<leader>mn", desc = "First row" },
      { "<leader>mN", desc = "Last row" },
      { "<leader>m[", desc = "Cell start" },
      { "<leader>m]", desc = "Cell end" },
      { "<leader>me", desc = "Echo cell pos" },
      { "<leader>m>", desc = "Move col right" },
      { "<leader>m<", desc = "Move col left" },

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
      { ";",     desc = "Flash — jump to char" },
      { "S",     desc = "Flash — treesitter jump" },
      { "`",     desc = "Go to mark (exact position)" },
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
      { "<C-n>", desc = "Multi-cursor — select word, add next" },
      { "<leader>A", desc = "Multi-cursor — select all matches" },

      -- ── Non-leader: Search chars ──
      { "f",     desc = "Find char forward" },
      { "F",     desc = "Find char backward" },
      { "t",     desc = "Till char forward" },
      { "T",     desc = "Till char backward" },
      { "'",     desc = "Repeat last f/t" },
      { ",",     desc = "Reverse last f/t" },

      -- ── Non-leader: Marks ──
      { "m",     desc = "Set mark (m + letter)" },
      { "`",     desc = "Jump to mark exact pos (` + letter)" },

      -- ── Non-leader: Misc ──
      { "U",     desc = "Redo" },
      { "<C-a>", desc = "Select all" },

      -- ── Visual mode: Markdown format ──
      { "<leader>b", mode = "v", desc = "Bold **" },
      { "<leader>i", mode = "v", desc = "Italic *" },
      { "<leader>h", mode = "v", desc = "Highlight ==" },
      { "<leader>s", mode = "v", desc = "Strikethrough ~~" },
      { "<leader>c", mode = "v", desc = "Inline code `" },
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
