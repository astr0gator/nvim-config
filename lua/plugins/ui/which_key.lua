-- Configure which-key hints and the global key hint entrypoint.
-- No icons (kept text-only by request). Leader layout: frequent actions are
-- top-level leaves; the rest are grouped under mnemonic prefixes.
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
      -- ── Frequent (top of menu) ──
      { "<leader>f",  desc = "Find files" },
      { "<leader>/",  desc = "Grep" },
      { "<leader>b",  desc = "Buffers" },
      { "<leader>d",  desc = "File tree" },
      { "<leader>;",  desc = "Command mode" },
      { "<leader>x",  desc = "Close buffer" },
      { "<leader>w",  desc = "Save" },
      { "<leader>a",  desc = "Select all" },

      -- ── e: edit / markdown format (normal + visual) ──
      { "<leader>e",  group = "edit / md format" },
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

      -- ── t: table ──
      { "<leader>t",   group = "table" },
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

      -- ── h: help ──
      { "<leader>h",  group = "help" },
      { "<leader>hh", desc = "Help pages" },
      { "<leader>hk", desc = "Keymaps" },
      { "<leader>h?", desc = "Key hints" },

      -- ── c: code / change ──
      { "<leader>c",  group = "code / change" },
      { "<leader>ca", desc = "Code action (LSP)" },
      { "<leader>cv", desc = "Change — void register" },

      -- ── o: options / theme ──
      { "<leader>o",  group = "options" },
      { "<leader>of", desc = "Theme — Flexoki" },
      { "<leader>ot", desc = "Theme — Tokyonight" },
      { "<leader>om", desc = "Theme — Miasma" },
      { "<leader>on", desc = "Theme — next" },
      { "<leader>op", desc = "Theme — previous" },
      { "<leader>ow", desc = "Toggle wrap" },
      { "<leader>oa", desc = "Autosave toggle" },

      -- ── p: palette ──
      { "<leader>p",  group = "palette" },
      { "<leader>pp", desc = "Command palette" },

      -- ── q: quit / save ──
      { "<leader>q",  group = "quit / save" },
      { "<leader>qq", desc = "Save and quit" },
      { "<leader>qQ", desc = "Quit without saving" },
      { "<leader>qZ", desc = "Save — all buffers" },

      -- ── s: swap ──
      { "<leader>s",  group = "swap" },
      { "<leader>ss", desc = "Swap — grab/swap value" },
      { "<leader>sc", desc = "Swap — cancel" },

      -- ── m: multi-cursor ──
      { "<leader>m",  group = "multi-cursor" },
      { "<leader>ma", desc = "Select all matches" },

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

      -- ── Non-leader: Misc ──
      { "U",     desc = "Redo" },
    },
  },
}
