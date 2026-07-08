-- Define the main Neovim keymaps used across the config.
local map = vim.keymap.set

local function close_current_buffer()
  local current = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(current) then
    return
  end

  local name = vim.api.nvim_buf_get_name(current)
  local label = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"

  if vim.bo[current].modified then
    local choice = vim.fn.confirm(
      ("Save changes to %s?"):format(label),
      "&Save\n&Discard\n&Cancel",
      1
    )

    if choice == 0 or choice == 3 then
      return
    end

    if choice == 1 then
      local ok, err = pcall(vim.cmd.write)
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
        return
      end
    end
  end

  local target
  for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if buf.bufnr ~= current then
      target = buf.bufnr
      break
    end
  end

  if target then
    vim.cmd.buffer(target)
  else
    vim.cmd.enew()
  end

  pcall(vim.api.nvim_buf_delete, current, { force = true })
end

_G.close_current_buffer = close_current_buffer
vim.api.nvim_create_user_command("Bclose", close_current_buffer, {
  desc = "Close buffer without quitting Neovim",
})

-- ── File ──────────────────────────────────────────────────────────────────────

map("n", "<leader>w", "<cmd>w<CR>",          { desc = "Save" })
map("n", "<leader>Z", "<cmd>Z<CR>",          { desc = "Save — all buffers" })
map("n", "<leader>q", "<Esc>:wq<CR>",        { desc = "Save and quit" })
map("n", "<leader>Q", "<Esc>:q!<CR>",        { desc = "Quit without saving" })
map("n", "<leader>x", close_current_buffer,  { desc = "Close buffer" })

-- TOC — fuzzy table of contents (telescope). Mirrors gO (which is markdown-only,
-- buffer-local). Works on any buffer with #-style headings; "No headings found"
-- otherwise. See lua/config/markdown_toc.lua.
map("n", "<leader>c", function() require("config.markdown_toc").pick() end, { desc = "TOC (table of contents)" })

-- ── Shift Passthrough ──────────────────────────────────────────────────────────

map({ "n", "i", "v" }, "<S-Space>", "<Space>", {})
map("i", "<Delete>", "<C-o>x", { noremap = true, desc = "Insert — forward delete" })
map("n", "<BS>", '"_X', { noremap = true, desc = "Delete char — backward, void register" })

-- ── Search ────────────────────────────────────────────────────────────────────

map("n", "<Esc>", function()
  -- Close Neo-tree if open, otherwise clear search
  if vim.bo.ft == "neo-tree" then
    vim.cmd("Neotree close")
  else
    vim.cmd("nohlsearch")
  end
end, { desc = "Close Neo-tree or clear search" })
-- Flash: Ctrl+s in command mode toggles flash overlay on search matches

-- ── Navigation ────────────────────────────────────────────────────────────────

map({ "n", "o" }, "gh", "^",                 { desc = "Navigate — to line (BOL, non-blank)" })
map("v", "gh", "^",                          { desc = "Navigate — to line (BOL, non-blank)" })
map({ "n", "o" }, "gl", "$",                 { desc = "Navigate — to line (EOL)" })
map("v", "gl", "$",                          { desc = "Navigate — to line (EOL)" })
map({ "n", "o" }, "<C-0>", "$",              { noremap = true, desc = "Navigate — to line (EOL)" })
-- Flash: s — jump by character, S — jump by treesitter node (functions, params, etc.)

-- ── Navigation: Flash ────────────────────────────────────────────────────────────
-- See lua/plugins/editor/flash.lua for flash.nvim keybindings:
--   s       — jump by character (labels appear, type label to zip there)
--   S       — jump by treesitter node (functions, params, etc.)
--   r       — remote flash (motion for operators: dr, cr, yr, etc.)
--   R       — treesitter search (motion for operators)
--   Ctrl+s  — toggle flash in command mode (/ or ? search)

-- ── Scroll ────────────────────────────────────────────────────────────────────

-- Scroll on both Ctrl-j/k and Alt-j/k. Ctrl-j/k use remap=true on purpose: they
-- route through neoscroll.nvim's <C-d>/<C-u> mappings so you get the SMOOTH
-- animation — do NOT switch them to noremap or a raw count, that bypasses the
-- plugin and snaps instantly. Alt-j/k = half-page jump that re-centers (zz).
-- Note: Ctrl-j/k leak into pickers/modals and Ctrl-j can read as <CR> in some,
-- closing the window — if that bites, drop them and use Alt only.
map({ "n", "v", "x" }, "<C-j>", "<C-d>",     { remap = true, silent = true, desc = "Scroll — half page down" })
map({ "n", "v", "x" }, "<C-k>", "<C-u>",     { remap = true, silent = true, desc = "Scroll — half page up" })
map({ "n", "v" }, "<A-j>", "<C-d>zz",        { noremap = true, silent = true, desc = "Scroll — half page down, center cursor" })
map({ "n", "v" }, "<A-k>", "<C-u>zz",        { noremap = true, silent = true, desc = "Scroll — half page up, center cursor" })
-- zz/zt/zb are native: they scroll the CONTENT so the current line is centered /
-- top / bottom. The cursor stays on its line (it does NOT move). H/M/L are the
-- opposite — they jump the cursor — so don't remap zz/zt/zb to those.

-- ── Buffer Cycle ───────────────────────────────────────────────────────────────

map("n", "<S-h>", "<cmd>bprevious<CR>",      { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>",          { desc = "Next buffer" })

-- ── Edit: Delete (cut to register) ───────────────────────────────────────────

map("n", "x",  'x',                          { noremap = true, desc = "Delete char — forward, cut to clipboard" })
map("n", "X",  'X',                          { noremap = true, desc = "Delete char — backward, cut to clipboard" })
map("n", "d",  '"_d',                        { noremap = true, desc = "Delete — with motion, void register (no clipboard)" })
map("v", "d",  '"_d',                        { noremap = true, desc = "Delete — with motion, void register (no clipboard)" })
map("n", "D",  '"_D',                        { noremap = true, desc = "Delete line — to end, void register (no clipboard)" })
map("n", "dd", '"_dd',                       { noremap = true, desc = "Delete line — void register (no clipboard)" })

-- ── Edit: Delete (void register) ──────────────────────────────────────────────


-- ── Edit: Change (cut to register) ───────────────────────────────────────────

map("n", "c",  '"_c',                        { noremap = true, desc = "Change — with motion, void register (no clipboard)" })
map("v", "c",  '"_c',                        { noremap = true, desc = "Change — with motion, void register (no clipboard)" })
map("n", "C",  '"_C',                        { noremap = true, desc = "Change line — to end (=c$), void register (no clipboard)" })
map("n", "cc", '"_cc',                       { noremap = true, desc = "Change line (=S), void register (no clipboard)" })
map("n", "s",  '"_s',                        { noremap = true, desc = "Substitute char — void register (no clipboard)" })
-- Flash: R — treesitter search motion (e.g. cR = change until a function definition)

-- ── Edit: Change (void register) ──────────────────────────────────────────────
-- Bare c / C / cc already change to the void register ("_c) — see lines above.
-- (Removed the redundant <leader>cv; bare c does the same thing.)

-- ── Edit: Move Lines ──────────────────────────────────────────────────────────

map("n", "<M-C-k>", ":m .-2<CR>",            { noremap = true, silent = true, desc = "Move line — up" })
map("n", "<M-C-j>", ":m .+1<CR>",            { noremap = true, silent = true, desc = "Move line — down" })
map("v", "<M-C-k>", ":m '<-2<CR>gv",         { noremap = true, silent = true, desc = "Move line — up, selection" })
map("v", "<M-C-j>", ":m '>+1<CR>gv",         { noremap = true, silent = true, desc = "Move line — down, selection" })

-- ── Edit: Indent ──────────────────────────────────────────────────────────────
-- Disabled to preserve Ctrl+i (jump forward, same keycode as Tab)
-- map("n", "<Tab>",   ">>",                    { noremap = true, silent = true })
-- map("n", "<S-Tab>", "<<",                    { noremap = true, silent = true })
-- map("v", "<Tab>",   ">gv",                   { noremap = true, silent = true })
-- map("v", "<S-Tab>", "<gv",                   { noremap = true, silent = true })

-- ── Edit: Comment ─────────────────────────────────────────────────────────────
-- See lua/plugins/editor/comment.lua for Ctrl+/ mapping

-- ── Edit: Insert Snippets ─────────────────────────────────────────────────────

map("i", "[[", "[ ] ",                       { noremap = true, desc = "Insert — empty checkbox [ ]" })

-- ── Edit: Insert Mode — Emacs Style ───────────────────────────────────────────

map("i", "<C-e>", "<C-o>$",                   { noremap = true, desc = "Insert — end of line" })
map("i", "<C-a>", "<C-o>^",                   { noremap = true, desc = "Insert — start of line" })
map("i", "<C-f>", "<C-o>a",                   { noremap = true, desc = "Insert — forward character" })
map("i", "<C-b>", "<C-o>h",                   { noremap = true, desc = "Insert — backward character" })

-- ── Yank Clean ─────────────────────────────────────────────────────────────────

map("n", "yc", function()
  local line = vim.fn.getline(".")
  line = line:gsub("^%s*%[.?%]%s*", "")   -- strip [ ], [x], etc. + surrounding space
  line = line:gsub("%s*|.*$", "")          -- strip | and everything after
  vim.fn.setreg('"', line)
  vim.fn.setreg("+", line)
  vim.notify("Yanked: " .. line, vim.log.levels.INFO)
end, { desc = "Yank clean — strip [ ] and | suffix" })

-- ── Select All ────────────────────────────────────────────────────────────────
-- <C-a> is Vim's increment-number key (restored to default); select-all lives on <leader>a.

map("n", "<leader>a", "ggVG", { desc = "Select all" })

-- "around all" text object: `aa` selects the entire buffer. Defined once in
-- operator-pending + visual mode, so it composes with every operator — no dialect:
--   yaa (yank) · daa (delete→VOID) · caa (change→VOID) · >aa (indent) · =aa (format) · vaa (select)
-- NOTE: `d`/`c` are remapped to the void register ("_d/_c) below, so daa/caa discard
-- text instead of cutting. For a real CUT of the whole buffer, use <leader>X (below).
-- `aa` adds no timeout over built-in `a`-objects: `a` is already ambiguous (aw/ap/as…).
map("o", "aa", "<Cmd>normal! ggVG<CR>", { silent = true, desc = "Object — entire buffer (around all)" })
map("x", "aa", "<Cmd>normal! ggVG<CR>", { silent = true, desc = "Object — entire buffer (around all)" })

-- Cut the entire buffer into the unnamed register ". Not `daa` — the normal-mode `d`
-- is void-bound ("_d), so `daa` deletes to /dev/null. `:%delete` is an Ex command: it
-- ignores the operator remap and cuts linewise to register ", matching `yaa`.
-- (Swap to `:%delete +` to cut to the system clipboard instead.)
map("n", "<leader>X", "<Cmd>%delete<CR>", { desc = "Cut — entire buffer to register" })

-- ── Clipboard ─────────────────────────────────────────────────────────────────

map("v", "<C-c>", '"+y',                     { noremap = true, silent = true, desc = "Clipboard — copy selection to system register (visual)" })
map("n", "<C-v>", '"+p',                     { noremap = true, silent = true, desc = "Clipboard — paste from system register (normal)" })
map("i", "<C-v>", "<C-r>+",                  { noremap = true, silent = true, desc = "Clipboard — paste from system register (insert)" })
map("v", "<C-v>", '"+p',                     { noremap = true, silent = true, desc = "Clipboard — paste from system register (visual)" })
map("v", "<C-x>", '"+d',                     { noremap = true, silent = true, desc = "Clipboard — cut selection to system register (visual)" })

-- ── Undo / Redo ───────────────────────────────────────────────────────────────

map("n", "U", "<C-r>",                       { desc = "Redo" })

-- ── Markdown: Format (<leader>e) ───────────────────────────────────────────
-- Normal mode wraps the inner word under the cursor; visual mode wraps the
-- selection. Repeating on already-wrapped text unwraps it (toggle).

-- Find an existing prefix/suffix pair on `line` overlapping [start_col, end_col].
-- Returns open_start, open_end, close_start, close_end (byte cols) or nil.
local function wrapped_span(line, start_col, end_col, prefix, suffix)
  local search_from = 1
  while true do
    local open_start, open_end = line:find(prefix, search_from, true)
    if not open_start then return nil end
    local close_start, close_end = line:find(suffix, open_end + 1, true)
    if not close_start then return nil end
    if start_col <= close_end and end_col >= open_start then
      return open_start, open_end, close_start, close_end
    end
    search_from = close_end + 1
  end
end

-- Wrap (or unwrap, if already wrapped) the single-line byte span [sc, ec] on row.
-- Core routine shared by md_word (explicit span) and md_wrap (one-line selection).
local function wrap_span(row, sc, ec, prefix, suffix)
  local line = vim.fn.getline(row)
  local plen, slen = #prefix, #suffix

  local open_start, open_end, close_start, close_end = wrapped_span(line, sc, ec, prefix, suffix)
  if open_start then
    vim.fn.setline(row, line:sub(1, open_start - 1) .. line:sub(open_end + 1, close_start - 1) .. line:sub(close_end + 1))
    return
  end

  -- Case 1: markers are INSIDE the span (user selected ==text==)
  local sel = line:sub(sc, ec)
  if sel:sub(1, plen) == prefix and sel:sub(-slen) == suffix then
    vim.fn.setline(row, line:sub(1, sc - 1) .. sel:sub(plen + 1, -slen - 1) .. line:sub(ec + 1))
    return
  end
  -- Case 2: markers are OUTSIDE the span (user selected just "text" inside ==text==)
  local before = line:sub(sc - plen, sc - 1)
  local after  = line:sub(ec + 1, ec + slen)
  if before == prefix and after == suffix then
    vim.fn.setline(row, line:sub(1, sc - plen - 1) .. line:sub(sc, ec) .. line:sub(ec + slen + 1))
    return
  end
  -- Wrap: add markers around the span
  vim.fn.setline(row, line:sub(1, sc - 1) .. prefix .. line:sub(sc, ec) .. suffix .. line:sub(ec + 1))
end

-- Visual mode: wrap the current selection (char/line/block, one or more lines).
local function md_wrap(prefix, suffix)
  local mode = vim.fn.mode()
  local s = (mode == "v" or mode == "V" or mode == "\22") and vim.fn.getpos("v") or vim.fn.getpos("'<")
  local e = (mode == "v" or mode == "V" or mode == "\22") and vim.fn.getcurpos() or vim.fn.getpos("'>")
  local sr, sc = s[2], s[3]
  local er, ec = e[2], e[3]
  local plen, slen = #prefix, #suffix

  if sr > er or (sr == er and sc > ec) then
    sr, sc, er, ec = er, ec, sr, sc
  end

  if mode == "V" then
    sc = 1
    ec = #vim.fn.getline(er)
  end

  if sr == er then
    wrap_span(sr, sc, ec, prefix, suffix)
    return
  end

  local first = vim.fn.getline(sr)
  local last = vim.fn.getline(er)
  local first_sel = first:sub(sc)
  local last_sel = last:sub(1, ec)
  if first_sel:sub(1, plen) == prefix and last_sel:sub(-slen) == suffix then
    vim.fn.setline(sr, first:sub(1, sc - 1) .. first_sel:sub(plen + 1))
    vim.fn.setline(er, last_sel:sub(1, -slen - 1) .. last:sub(ec + 1))
    return
  end
  local before = first:sub(sc - plen, sc - 1)
  local after  = last:sub(ec + 1, ec + slen)
  if before == prefix and after == suffix then
    vim.fn.setline(sr, first:sub(1, sc - plen - 1) .. first:sub(sc))
    vim.fn.setline(er, last:sub(1, ec) .. last:sub(ec + slen + 1))
    return
  end
  vim.fn.setline(sr, first:sub(1, sc - 1) .. prefix .. first:sub(sc))
  vim.fn.setline(er, last:sub(1, ec) .. suffix .. last:sub(ec + 1))
end

-- Normal mode: wrap the keyword run under the cursor. Computes the span and calls
-- wrap_span directly — no mode() or '<'> dependency — so it always targets the
-- word regardless of stale marks or a lingering visual selection.
local function md_word(prefix, suffix)
  local row, col = vim.fn.line("."), vim.fn.col(".")
  local line = vim.fn.getline(row)
  if line == "" then return end
  local ch = line:sub(col, col)
  if ch == "" or ch:match("%s") then return end
  -- match `iw`: a run of the same class (keyword chars, or other non-space)
  local function same(s)
    if ch:match("[%w_]") then return s:match("[%w_]") ~= nil end
    return s ~= "" and s:match("[%w_%s]") == nil
  end
  local sc = col
  while sc > 1 and same(line:sub(sc - 1, sc - 1)) do sc = sc - 1 end
  local n = #line
  local ec = col
  while ec < n and same(line:sub(ec + 1, ec + 1)) do ec = ec + 1 end
  wrap_span(row, sc, ec, prefix, suffix)
  -- land on the word so a repeat press toggles instead of re-wrapping
  local nl = vim.fn.getline(row)
  local c = sc
  while c <= #nl and not same(nl:sub(c, c)) do c = c + 1 end
  if c <= #nl then vim.api.nvim_win_set_cursor(0, { row, c - 1 }) end
end

-- Visual mode: wrap the selection. Highlight needs Esc + redraw to refresh conceal.
local function md_visual(prefix, suffix)
  md_wrap(prefix, suffix)
  if suffix == "==" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    vim.cmd("redraw")
  end
end

local md_actions = {
  b = { pre = "**", suf = "**", desc = "Markdown — bold" },
  i = { pre = "*",  suf = "*",  desc = "Markdown — italic" },
  h = { pre = "==", suf = "==", desc = "Markdown — highlight" },
  s = { pre = "~~", suf = "~~", desc = "Markdown — strikethrough" },
  c = { pre = "`",  suf = "`",  desc = "Markdown — inline code" },
}
for key, a in pairs(md_actions) do
  map("n", "<leader>e" .. key, function() md_word(a.pre, a.suf) end, { desc = a.desc })
  map("v", "<leader>e" .. key, function() md_visual(a.pre, a.suf) end, { desc = a.desc })
end

-- ── Misc ──────────────────────────────────────────────────────────────────────

-- ";" kept as native f/t repeat (reverted from ":" mapping)
map("n", "<leader>;", ":",                    { desc = "Command mode" })
map("t", "<Esc>", "<C-\\><C-n>",             { noremap = true, silent = true, desc = "Exit terminal mode to normal" })

-- ── Which-key ─────────────────────────────────────────────────────────────────

map("n", "<leader>h?", function()
  require("which-key").show({ global = true })
end, { desc = "Show key hints" })

-- ── Options ───────────────────────────────────────────────────────────────────

map("n", "<leader>of", function() require("config.theme").use_flexoki()  end, { desc = "Theme — Flexoki" })
map("n", "<leader>ot", function() require("config.theme").use_tokyonight() end, { desc = "Theme — Tokyonight" })
map("n", "<leader>om", function() require("config.theme").use_miasma()   end, { desc = "Theme — Miasma" })
map("n", "<leader>on", function() require("config.theme").cycle(1)       end, { desc = "Theme — next" })
map("n", "<leader>op", function() require("config.theme").cycle(-1)      end, { desc = "Theme — previous" })
map("n", "<leader>ow", function()
  vim.opt_local.wrap = not vim.opt_local.wrap:get()
end, { desc = "Toggle wrap" })
map("n", "<leader>oa", function() require("config.automation.autosave").toggle() end, { desc = "Autosave toggle" })

-- ── Manipulate — swap ─────────────────────────────────────────────────────────
-- Swap lives under <leader>m (manipulate), alongside multi-cursor <leader>ma.
-- The first-level <leader>s slot is freed by this move.

map("n", "<leader>ms", function() require("config.swap").swap() end,   { desc = "Swap — grab/swap value" })
map("n", "<leader>mc", function() require("config.swap").cancel() end, { desc = "Swap — cancel" })
