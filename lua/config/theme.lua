-- Manage theme selection, auto mode, and cursor color behavior.
local M = {
  auto_mode = true,
  order = { "flexoki", "tokyonight", "miasma" },
}

local function load_plugin(name)
  local ok, lazy = pcall(require, "lazy")
  if ok then
    lazy.load({ plugins = { name } })
  end
end

function M.is_auto_mode()
  return M.auto_mode
end

function M.use_flexoki()
  M.auto_mode = true

  local ok, auto_dark_mode = pcall(require, "auto-dark-mode")
  if ok and auto_dark_mode.disable then
    auto_dark_mode.disable()
  end

  vim.cmd.colorscheme "flexoki"

  if ok and auto_dark_mode.init then
    auto_dark_mode.init()
    return
  end

  M.set_cursor()
end

function M.use_miasma()
  M.auto_mode = false

  local ok, auto_dark_mode = pcall(require, "auto-dark-mode")
  if ok and auto_dark_mode.disable then
    auto_dark_mode.disable()
  end

  load_plugin "miasma"
  vim.o.background = "dark"
  vim.cmd.colorscheme "miasma"
  vim.schedule(function()
    M.set_dark_background()
    M.set_cursor()
  end)
end

function M.use_tokyonight()
  M.auto_mode = false

  local ok, auto_dark_mode = pcall(require, "auto-dark-mode")
  if ok and auto_dark_mode.disable then
    auto_dark_mode.disable()
  end

  load_plugin "tokyonight"
  vim.o.background = "dark"
  vim.cmd.colorscheme "tokyonight"
  vim.schedule(function()
    M.set_dark_background()
    M.set_cursor()
  end)
end

function M.apply(name)
  if name == "miasma" then
    M.use_miasma()
    return
  end

  if name == "tokyonight" then
    M.use_tokyonight()
    return
  end

  M.use_flexoki()
end

function M.current()
  if vim.g.colors_name == "miasma" then
    return "miasma"
  end

  if vim.g.colors_name == "tokyonight" then
    return "tokyonight"
  end

  return "flexoki"
end

function M.cycle(step)
  local current = M.current()
  local index = 1

  for i, name in ipairs(M.order) do
    if name == current then
      index = i
      break
    end
  end

  local next_index = ((index - 1 + step) % #M.order) + 1
  M.apply(M.order[next_index])
end

function M.apply_auto_colorscheme()
  if not M.auto_mode then
    return
  end

  vim.schedule(function()
    vim.cmd.colorscheme "flexoki"
    M.set_cursor()
  end)
end

-- Custom dark background color
M.custom_dark_bg = "#24283B"

function M.set_dark_background()
  vim.api.nvim_set_hl(0, "Normal", { bg = M.custom_dark_bg })
  vim.api.nvim_set_hl(0, "NormalNC", { bg = M.custom_dark_bg })
end

-- Cursor color
-- M.cursor_color = "#f96714"
M.cursor_color = "#e85c05"
 
function M.set_cursor()
  vim.api.nvim_set_hl(0, "Cursor", { bg = M.cursor_color })
  vim.api.nvim_set_hl(0, "lCursor", { bg = M.cursor_color })
  vim.api.nvim_set_hl(0, "CursorIM", { bg = M.cursor_color })
  vim.api.nvim_set_hl(0, "TermCursor", { bg = M.cursor_color })
end

function M.set_line_numbers()
  vim.api.nvim_set_hl(0, "LineNr", { link = "Comment" })
  vim.api.nvim_set_hl(0, "CursorLineNr", { link = "Comment" })
end

function M.register_commands()
  vim.api.nvim_create_user_command("ThemeFlexoki", function()
    M.use_flexoki()
  end, { desc = "Use Flexoki with auto dark/light mode" })

  vim.api.nvim_create_user_command("ThemeMiasma", function()
    M.use_miasma()
  end, { desc = "Use the Miasma colorscheme" })

  vim.api.nvim_create_user_command("ThemeTokyonight", function()
    M.use_tokyonight()
  end, { desc = "Use the Tokyonight colorscheme" })

  vim.api.nvim_create_user_command("ThemeNext", function()
    M.cycle(1)
  end, { desc = "Switch to the next theme" })

  vim.api.nvim_create_user_command("ThemePrev", function()
    M.cycle(-1)
  end, { desc = "Switch to the previous theme" })
end

return M
