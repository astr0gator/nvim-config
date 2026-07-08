-- Installs a locally-patched markdown_inline highlights query, replacing
-- nvim-treesitter's bundled one (see after/queries/markdown_inline/highlights.scm
-- for what changed and why — file-based after/queries loading MERGES with
-- the bundled query rather than replacing it, so that .scm file alone has no
-- effect; vim.treesitter.query.set() is what actually installs a
-- replacement). Must run before any markdown_inline buffer is parsed, so
-- this is required eagerly from init.lua, not lazy-loaded.
local M = {}

function M.setup()
  local path = vim.fn.stdpath("config") .. "/after/queries/markdown_inline/highlights.scm"
  local lines = vim.fn.readfile(path)
  vim.treesitter.query.set("markdown_inline", "highlights", table.concat(lines, "\n"))
end

return M
