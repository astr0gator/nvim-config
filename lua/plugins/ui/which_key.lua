-- Configure which-key hints and the global key hint entrypoint.
-- No icons (text-only by request). Menu ordered via per-entry `order` so the
-- frequent actions fill the first column(s) and the basics/groups come after.
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
    icons = { mappings = false, separator = " → ", group = "" },
    spec = {
      -- ── Discovery (order 1–9): things you want hints for ──
      { "<leader>f",  desc = "Find files",       order = 1 },
      { "<leader>/",  desc = "Grep",             order = 2 },
      { "<leader>b",  desc = "Buffers",          order = 3 },
      { "<leader>x",  desc = "Close buffer",     order = 4 },
      { "<leader>d",  desc = "File tree",        order = 5 },
      { "<leader>e",  group = "edit / md format", order = 6 },
      { "<leader>t",  group = "table",           order = 7 },
      { "<leader>;",  desc = "Command mode",     order = 8 },
      { "<leader>a",  desc = "Select all",       order = 9 },
      -- memorized file ops — parked at the very end (order 90+); you know these
      { "<leader>w",  desc = "Save",             order = 90 },
      { "<leader>q",  desc = "Save and quit",    order = 91 },
      { "<leader>Q",  desc = "Quit (no save)",   order = 92 },
      { "<leader>Z",  desc = "Save — all buffers", order = 93 },

      -- ── edit / md format (normal + visual) ──
      { "<leader>eb", desc = "Bold **" },
      { "<leader>ei", desc = "Italic *" },
      { "<leader>eh", desc = "Highlight ==" },
      { "<leader>es", desc = "Strikethrough ~~" },
      { "<leader>ec", desc = "Inline code `" },
      { "<leader>e",  group = "edit / md format", mode = "v" },
      { "<leader>eb", mode = "v", desc = "Bold **" },
      { "<leader>ei", mode = "v", desc = "Italic *" },
      { "<leader>eh", mode = "v", desc = "Highlight ==" },
      { "<leader>es", mode = "v", desc = "Strikethrough ~~" },
      { "<leader>ec", mode = "v", desc = "Inline code `" },

      -- ── table ──
      { "<leader>tr",  desc = "Realign" },
      { "<leader>tf",  desc = "Add formula" },
      { "<leader>tF",  desc = "Eval formulas" },
      { "<leader>ts",  desc = "Sort column asc" },
      { "<leader>tS",  desc = "Sort column desc" },
      { "<leader>tdd", desc = "Delete row" },
      { "<leader>tdc", desc = "Delete column" },
      { "<leader>tic", desc = "Insert col after" },
      { "<leader>tiC", desc = "Insert col before" },
      { "<leader>tir", desc = "Insert row below" },
      { "<leader>tiR", desc = "Insert row above" },
      { "<leader>tn",  desc = "First row" },
      { "<leader>tN",  desc = "Last row" },
      { "<leader>t[",  desc = "Cell start" },
      { "<leader>t]",  desc = "Cell end" },
      { "<leader>te",  desc = "Echo cell pos" },
      { "<leader>t>",  desc = "Move col right" },
      { "<leader>t<",  desc = "Move col left" },

      -- ── Basics / config groups (order 20+) ──
      { "<leader>h",  group = "help",   order = 20 },
      { "<leader>c",  group = "code",   order = 21 },
      { "<leader>o",  group = "options", order = 22 },
      { "<leader>p",  group = "palette", order = 23 },
      { "<leader>s",  group = "swap",   order = 24 },
      { "<leader>m",  group = "multi-cursor", order = 25 },

      { "<leader>hh", desc = "Help pages" },
      { "<leader>hk", desc = "Keymaps" },
      { "<leader>h?", desc = "Key hints" },

      { "<leader>ca", desc = "Code action (LSP)" },

      { "<leader>of", desc = "Theme — Flexoki" },
      { "<leader>ot", desc = "Theme — Tokyonight" },
      { "<leader>om", desc = "Theme — Miasma" },
      { "<leader>on", desc = "Theme — next" },
      { "<leader>op", desc = "Theme — previous" },
      { "<leader>ow", desc = "Toggle wrap" },
      { "<leader>oa", desc = "Autosave toggle" },

      { "<leader>pp", desc = "Command palette" },

      { "<leader>ss", desc = "Swap — grab/swap value" },
      { "<leader>sc", desc = "Swap — cancel" },

      { "<leader>ma", desc = "Select all matches" },

      -- ── Non-leader: Scroll ──
      { "<A-j>", desc = "Scroll — half page down" },
      { "<A-k>", desc = "Scroll — half page up" },

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

      -- ── Non-leader: Numbers ──
      { "<C-a>", desc = "Increment number" },
      { "<C-x>", desc = "Decrement number" },

      -- ── Non-leader: Yank ──
      { "yaa",   desc = "Yank — entire buffer" },

      -- ── Non-leader: Misc ──
      { "U",     desc = "Redo" },
    },
  },
}
