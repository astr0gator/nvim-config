-- Multi-cursor editing (VSCode-like behavior).
return {
  "smoka7/multicursors.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvimtools/hydra.nvim",
  },
  opts = {},
  keys = {
    {
      "<C-n>",
      function()
        require("multicursors").start()
      end,
      mode = { "n", "x" },
      desc = "Multi-cursor — select word under cursor",
    },
  },
}
