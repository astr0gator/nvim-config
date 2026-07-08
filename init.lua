-- Bootstrap the Neovim config by loading core config modules and tool setup.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require "config.options"
require "config.lazy"
require "config.keymaps"
require "config.autocmds"
require "config.tabline"
require("config.markdown_inline_query").setup()
