<!-- Describe the repo structure, editing rules, and local verification workflow. -->
# Neovim Config

This config uses plain `lazy.nvim`, not a distro.

The rule of the project is simple:
- `init.lua` should stay tiny.
- `lua/config/` is for editor behavior.
- `lua/config/automation/` is for custom automations that are not plugins.
- `lua/plugins/` is grouped by scope, with one plugin per file. Each plugin file must start with a comment describing what the plugin does.
- `lua/tools/` is for external sync and maintenance helpers.
- Keep junk out of the repo root and out of `lua/`.
- Every maintained source, doc, and script file should start with a short purpose header.
- Exception: machine-generated or strict-format files that cannot safely hold comments, like `lazy-lock.json`, keep their format unchanged.

## Editing Convention

When you want to change something, use this rule:
- general Neovim behavior: `lua/config/options.lua`
- keymaps: `lua/config/keymaps.lua`
- automatic editor actions: `lua/config/autocmds.lua`
- custom automations: `lua/config/automation/`
- theme behavior and theme switching: `lua/config/theme.lua`
- plugin manager setup: `lua/config/lazy.lua`
- editor plugins: `lua/plugins/editor/`
- LSP plugins: `lua/plugins/lsp/`
- UI plugins: `lua/plugins/ui/`
- theme plugins: `lua/plugins/themes/`
- external sync and maintenance helpers: `lua/tools/`

Try not to add logic to `init.lua` unless it truly belongs at startup.

## Regression Checks

If you touch markdown checkbox mappings in `lua/plugins/editor/bullets.lua`, run:

```sh
nvim --headless -n -u NONE "+lua dofile('tests/markdown_checkbox_mappings.lua')" "+qall!"
```

This guards `ta`, `to`, and `tO`, including the easy-to-break "space after `[ ]`" insert behavior.

## Inside Neovim

Useful commands and keys:
- command palette: `<leader>p`
- file search: `<leader>f`
- text search: `<leader>/`
- keymap search: `<leader>k`
- show key hints: `<leader>?`
- close buffer: `<leader>x`
- buffers: `<leader>b`
- help pages: `<leader>h`
- file tree: `<leader>e`
- switch to default auto Flexoki: `<leader>tf` or `:ThemeFlexoki`
- switch to Tokyonight: `<leader>tt` or `:ThemeTokyonight`
- switch to Miasma: `<leader>tm` or `:ThemeMiasma`
- next theme: `<leader>tn` or `:ThemeNext`
- previous theme: `<leader>tp` or `:ThemePrev`
- toggle table mode: `<leader>tb` (markdown files only)
- realign table: `<leader>tr` (markdown files only)
- markdown files use visual wrapping by default, but pipe tables still do not support true multi-line cells

## Theme Notes

Default behavior is Flexoki with automatic dark/light switching.

`miasma.nvim` is installed, but it is intentionally not the default.

`tokyonight.nvim` is also installed as an extra dark theme.

Use `:ThemeMiasma` instead of plain `:colorscheme miasma` so auto dark/light mode is paused correctly.

Use `:ThemeFlexoki` to return to the default behavior.
