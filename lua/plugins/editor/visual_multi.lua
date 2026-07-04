-- Multi-cursor editing (VSCode-like behavior).
-- vim-visual-multi: <C-n> selects the word under the cursor and adds the next
-- match; keep tapping <C-n> to add more. <leader>ma selects ALL matches at once.
-- q skips a region, Q removes it, c/d/i/a act on every cursor, Esc exits.
return {
  "mg979/vim-visual-multi",
  event = "VeryLazy",
  init = function()
    vim.g.VM_maps = {
      ["Find Under"] = "<C-n>",
      ["Find Subword Under"] = "<C-n>",
      ["Select All"] = "<leader>ma",
      ["Skip Region"] = "q",
      ["Remove Region"] = "Q",
      ["Add Cursor Down"] = "<C-Down>",
      ["Add Cursor Up"] = "<C-Up>",
    }
  end,
}
