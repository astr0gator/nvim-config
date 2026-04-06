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

map({ "n", "v" }, "<A-j>", "<C-d>zz",        { noremap = true, silent = true, desc = "Scroll — half page down, center cursor" })
map({ "n", "v" }, "<A-k>", "<C-u>zz",        { noremap = true, silent = true, desc = "Scroll — half page up, center cursor" })
map({ "n", "v", "x" }, "<C-j>", "<C-d>",    { remap = true, silent = true, desc = "Scroll — half page down" })
map({ "n", "v", "x" }, "<C-k>", "<C-u>",    { remap = true, silent = true, desc = "Scroll — half page up" })
map("n", "zt", "H", { noremap = true, desc = "Scroll — current line to top" })
map("n", "zz", "M", { noremap = true, desc = "Scroll — current line to center" })
map("n", "zb", "L", { noremap = true, desc = "Scroll — current line to bottom" })

-- ── Buffer Cycle ───────────────────────────────────────────────────────────────

map("n", "<S-h>", "<cmd>bprevious<CR>",      { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>",          { desc = "Next buffer" })

-- ── Edit: Delete (cut to register) ───────────────────────────────────────────

map("n", "x",  'x',                          { noremap = true, desc = "Delete char — forward, cut to register" })
map("n", "X",  'X',                          { noremap = true, desc = "Delete char — backward, cut to register" })
map("n", "d",  'd',                          { noremap = true, desc = "Delete — with motion, cut to register" })
map("v", "d",  'd',                          { noremap = true, desc = "Delete — with motion, cut to register" })
map("n", "D",  'D',                          { noremap = true, desc = "Delete line — to end, cut to register" })
map("n", "dd", 'dd',                         { noremap = true, desc = "Delete line — cut to register" })
-- Flash: r — remote flash motion for operators (e.g. dr + char = delete to any char on screen)

-- ── Edit: Delete (void register) ──────────────────────────────────────────────

map("n", "<leader>d", '"_d',                 { noremap = true, desc = "Delete — void register" })
map("v", "<leader>d", '"_d',                 { noremap = true, desc = "Delete — void register" })

-- ── Edit: Change (cut to register) ───────────────────────────────────────────

map("n", "c",  'c',                          { noremap = true, desc = "Change — with motion, cut to register" })
map("v", "c",  'c',                          { noremap = true, desc = "Change — with motion, cut to register" })
map("n", "C",  'C',                          { noremap = true, desc = "Change line — to end, cut to register" })
map("n", "cc", 'cc',                         { noremap = true, desc = "Change line — cut to register" })
-- Flash: R — treesitter search motion (e.g. cR = change until a function definition)

-- ── Edit: Change (void register) ──────────────────────────────────────────────

map("n", "<leader>c", '"_c',                 { noremap = true, desc = "Change — void register" })
map("v", "<leader>c", '"_c',                 { noremap = true, desc = "Change — void register" })

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

-- ── Clipboard ─────────────────────────────────────────────────────────────────

map("v", "<C-c>", '"+y',                     { noremap = true, silent = true, desc = "Clipboard — copy selection to system register (visual)" })
map("n", "<C-v>", '"+p',                     { noremap = true, silent = true, desc = "Clipboard — paste from system register (normal)" })
map("i", "<C-v>", "<C-r>+",                  { noremap = true, silent = true, desc = "Clipboard — paste from system register (insert)" })
map("v", "<C-v>", '"+p',                     { noremap = true, silent = true, desc = "Clipboard — paste from system register (visual)" })
map("v", "<C-x>", '"+d',                     { noremap = true, silent = true, desc = "Clipboard — cut selection to system register (visual)" })

-- ── Undo / Redo ───────────────────────────────────────────────────────────────

map("n", "U", "<C-r>",                       { desc = "Redo" })

-- ── Misc ──────────────────────────────────────────────────────────────────────

-- ";" kept as native f/t repeat (reverted from ":" mapping)
map("n", "<leader>;", ":",                    { desc = "Command mode" })
map("t", "<Esc>", "<C-\\><C-n>",             { noremap = true, silent = true, desc = "Exit terminal mode to normal" })

-- ── Which-key ─────────────────────────────────────────────────────────────────

map("n", "<leader>?", function()
  require("which-key").show({ global = true })
end, { desc = "Show key hints" })

-- ── Theme ─────────────────────────────────────────────────────────────────────

map("n", "<leader>tf", function() require("config.theme").use_flexoki()  end, { desc = "Theme — Flexoki" })
map("n", "<leader>tt", function() require("config.theme").use_tokyonight() end, { desc = "Theme — Tokyonight" })
map("n", "<leader>tm", function() require("config.theme").use_miasma()   end, { desc = "Theme — Miasma" })
map("n", "<leader>tn", function() require("config.theme").cycle(1)       end, { desc = "Theme — next" })
map("n", "<leader>tp", function() require("config.theme").cycle(-1)      end, { desc = "Theme — previous" })

-- ── Toggle ────────────────────────────────────────────────────────────────────

map("n", "<leader>ta", function() require("config.automation.autosave").toggle() end, { desc = "Toggle autosave on focus lost" })
