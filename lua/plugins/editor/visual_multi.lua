-- Multi-cursor editing (VSCode-like behavior).
-- vim-visual-multi: Ctrl+N selects word, n adds next, <Leader>A selects all matches,
-- q skips, c/d/i/a work like Vim, Esc exits. (<C-a> kept free for "select all text".)
return {
  "mg979/vim-visual-multi",
  event = "VeryLazy",
  init = function()
    vim.g.VM_maps = {
      ["Find Under"] = "<C-n>",
      ["Find Subword Under"] = "<C-n>",
      -- "Select All" left at plugin default (<Leader>A) so it doesn't clobber <C-a>.
      ["Skip Region"] = "q",
      ["Remove Region"] = "Q",
      ["Add Cursor Down"] = "<C-Down>",
      ["Add Cursor Up"] = "<C-Up>",
    }
  end,
}
