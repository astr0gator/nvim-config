-- In-buffer markdown rendering: styled headings, pretty tables, toggleable
-- checkboxes (rendered as icons), concealed links, highlighted code blocks.
-- Plain text stays intact underneath — this is display only. Toggling
-- checkboxes still uses bullets.vim's `td`; this just shows the state.
-- Toggle with :RenderMarkdown toggle if you ever want raw text.
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  opts = {},
}
