-- Test markdown folding + <CR>/<C-CR> behaviour + mkview/loadview persistence.
-- These live in lua/config/autocmds.lua. We load the REAL autocmds.lua — its
-- setup deps (autosave, task_ids) are pure vim.api, safe under -u NONE — by
-- putting the repo's lua/ on package.path so autocmds.lua's internal require()s
-- resolve. Covers the behaviours promised for markdown buffers so they can't
-- silently regress: <CR> = list-continue / fold-toggle / line-down,
-- <C-CR> = toggle all folds, and fold state survives a window round-trip.

local cwd = vim.fn.getcwd()
package.path = cwd .. "/lua/?.lua;" .. cwd .. "/lua/?/init.lua;" .. package.path
dofile(cwd .. "/lua/config/autocmds.lua") -- registers _G.markdown_* + FileType autocmd

local function assert_eq(actual, expected, label)
  if vim.deep_equal(actual, expected) then return end
  error(("%s\nexpected: %s\nactual:   %s"):format(label, vim.inspect(expected), vim.inspect(actual)))
end

-- Set buffer content + cursor and trigger the markdown FileType autocmd
-- (foldmethod=expr, foldexpr, <CR>/<C-CR> keymaps, wrap, persistence autocmds).
local function set_buf(lines, cursor)
  vim.bo.filetype = "markdown"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, cursor)
end

-- foldexpr: a `#` heading starts a level-1 fold; body lines inherit it.
set_buf({ "# Heading", "body one", "body two" }, { 1, 0 })
assert_eq(vim.wo.foldmethod, "expr", "foldmethod = expr")
assert_eq(vim.fn.foldlevel(1), 1, "H1 line has fold level 1")
assert_eq(vim.fn.foldlevel(2), 1, "body line inherits fold level 1")

-- <CR> toggles a fold on a foldable (heading) line.
vim.wo.foldlevel = 0 -- close everything
assert_eq(vim.fn.foldclosed(1), 1, "fold closed at line 1")
_G.markdown_enter() -- heading line, foldlevel > 0 -> za (open)
assert_eq(vim.fn.foldclosed(1), -1, "<CR> opened the fold under the heading")
_G.markdown_enter() -- toggle again -> close
assert_eq(vim.fn.foldclosed(1), 1, "<CR> closed the fold again")

-- <CR> moves down on a non-foldable line (no heading -> foldlevel 0).
set_buf({ "plain one", "plain two", "plain three" }, { 1, 0 })
assert_eq(vim.fn.foldlevel("."), 0, "plain line has fold level 0")
_G.markdown_enter() -- -> normal! <CR> (down one line, first non-blank)
assert_eq(vim.api.nvim_win_get_cursor(0)[1], 2, "<CR> moves down on a non-foldable line")

-- <C-CR> (toggle_all_folds): all open -> "zM"; any closed -> "zR".
set_buf({ "# H", "body" }, { 1, 0 })
vim.wo.foldlevel = 99 -- all open
assert_eq(_G.markdown_toggle_all_folds(), "zM", "all open -> zM (close all)")
vim.wo.foldlevel = 0 -- all closed
assert_eq(_G.markdown_toggle_all_folds(), "zR", "any closed -> zR (open all)")

-- mkview/loadview round-trip restores folds (what BufWinLeave/BufWinEnter run).
local tmp = vim.fn.tempname()
vim.fn.writefile({ "# Saved heading", "folded body line" }, tmp)
vim.cmd("edit " .. vim.fn.fnameescape(tmp))
vim.bo.filetype = "markdown"
-- Under -u NONE / isolated XDG_STATE_HOME the default viewdir doesn't exist and
-- mkview can't create it (E739), so make our own.
local viewdir = vim.fn.tempname() .. "-view"
vim.fn.mkdir(viewdir, "p")
vim.cmd("set viewdir=" .. vim.fn.fnameescape(viewdir))
vim.wo.foldlevel = 0
assert_eq(vim.fn.foldclosed(1), 1, "fold closed before mkview")
vim.cmd("mkview")
vim.wo.foldlevel = 99 -- wipe visible fold state
assert_eq(vim.fn.foldclosed(1), -1, "fold open before loadview")
vim.cmd("loadview")
assert_eq(vim.fn.foldclosed(1), 1, "loadview restored the closed fold")

-- Persistence autocmds are wired per markdown buffer.
assert_eq(#vim.api.nvim_get_autocmds({ event = "BufWinLeave", buffer = 0 }) > 0, true,
  "BufWinLeave (mkview) autocmd registered for markdown buffer")
assert_eq(#vim.api.nvim_get_autocmds({ event = "BufWinEnter", buffer = 0 }) > 0, true,
  "BufWinEnter (loadview) autocmd registered for markdown buffer")

vim.fn.delete(tmp)
vim.fn.delete(viewdir, "rf")

print("ok: markdown fold / <CR> / <C-CR> / mkview-loadview tests passed")
