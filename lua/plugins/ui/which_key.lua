-- Configure which-key hints and the global key hint entrypoint.
--
-- Ordering: `order` on each entry controls menu position. NOTE — `order` is a
-- real which-key SORTER, but it is NOT a registered spec field, so `order=` is
-- silently dropped unless we register it (see `config` below). Without that,
-- the menu falls back to group → alphabetical, ignoring every `order`.
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
      -- ── Featured four (front, in this order) ──
      { "<leader>c", desc = "TOC",             order = 1 },
      { "<leader>t", group = "table",          order = 2 },
      { "<leader>e", group = "edit",           order = 3 },
      { "<leader>m", group = "manipulate",     order = 4 },

      -- ── Discovery / navigation ──
      { "<leader>f",  desc = "Find files",       order = 5 },
      { "<leader>/",  desc = "Grep",             order = 6 },
      { "<leader>d",  desc = "File tree",        order = 7 },
      { "<leader>;",  desc = "Command mode",     order = 8 },
      { "<leader>o",  group = "options",         order = 9 },
      { "<leader>p",  group = "palette",         order = 10 },

      -- ── File ops ──
      { "<leader>w",  desc = "Save",             order = 11 },
      { "<leader>q",  desc = "Save and quit",    order = 12 },
      { "<leader>k",  desc = "Quit (no save)",   order = 13 },
      { "<leader>Z",  desc = "Save — all buffers", order = 14 },

      -- ── Buffers (together, near the end; x after b) ──
      { "<leader>b",  desc = "Buffers",          order = 15 },
      { "<leader>x",  desc = "Close buffer",     order = 16 },

      -- ── Tail: select-all, then help last ──
      { "<leader>a",  desc = "Select all",       order = 17 },
      { "<leader>h",  group = "help",            order = 18 },

      -- ── edit (normal + visual) ──
      { "<leader>eb", desc = "Bold **" },
      { "<leader>ei", desc = "Italic *" },
      { "<leader>eh", desc = "Highlight ==" },
      { "<leader>es", desc = "Strikethrough ~~" },
      { "<leader>ec", desc = "Inline code `" },
      { "<leader>e",  group = "edit", mode = "v" },
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

      -- ── manipulate (multi-cursor + swap) ──
      { "<leader>ma", desc = "Select all matches" },
      { "<leader>ms", desc = "Swap — grab/swap value" },
      { "<leader>mc", desc = "Swap — cancel" },

      -- ── options ──
      { "<leader>of", desc = "Theme — Flexoki" },
      { "<leader>ot", desc = "Theme — Tokyonight" },
      { "<leader>om", desc = "Theme — Miasma" },
      { "<leader>on", desc = "Theme — next" },
      { "<leader>op", desc = "Theme — previous" },
      { "<leader>ow", desc = "Toggle wrap" },
      { "<leader>oa", desc = "Autosave toggle" },

      -- ── palette ──
      { "<leader>pp", desc = "Command palette" },

      { "<leader>hh", desc = "Help pages" },
      { "<leader>hk", desc = "Keymaps" },
      { "<leader>h?", desc = "Key hints" },

      -- ── Non-leader: Scroll ──
      { "<C-j>", desc = "Scroll — half page down" },
      { "<C-k>", desc = "Scroll — half page up" },
      { "<A-j>", desc = "Scroll — half page down, center cursor" },
      { "<A-k>", desc = "Scroll — half page up, center cursor" },

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
      { "gO",    desc = "TOC (markdown)" },
      { "gK",    desc = "Code action (LSP)" },
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
  config = function(_, opts)
    -- Register `order` as a spec field so per-entry `order=` propagates
    -- spec → mapping → node → item (the `order` sorter already reads item.order;
    -- without this, `order=` is silently dropped and the menu stays alpha).
    require("which-key.mappings").fields.order = {}

    require("which-key").setup(opts)

    -- Neutral, uniform text: keys + descriptions + groups all use the float's
    -- normal color (WhichKeyNormal → NormalFloat, so bg matches — no patches).
    -- which-key sets its defaults with default = true, so this override wins.
    local function neutral_text()
      for _, hl in ipairs({ "WhichKey", "WhichKeyDesc", "WhichKeyGroup" }) do
        vim.api.nvim_set_hl(0, hl, { link = "NormalFloat" })
      end
    end
    neutral_text()
    vim.api.nvim_create_autocmd("ColorScheme", {
      desc = "which-key: neutral text color",
      callback = vim.schedule_wrap(neutral_text),
    })
  end,
}
