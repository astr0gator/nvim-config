-- In-buffer markdown rendering (render-markdown.nvim), customized to a calm,
-- non-pink, theme-matched palette. Safe to lazy-load on markdown (unlike markview).
--
-- Scroll-friendly choices (the whole point vs markview):
--   render_modes = { n, c, t }  -> NOT insert. Insert mode shows RAW text, so
--                                  no re-render while typing; raw text only after i.
--   anti_conceal = false        -> do NOT reveal the cursor line on j/k. Normal
--                                  mode stays fully rendered.
--   concealcursor rendered="n"  -> keep conceal active on the cursor line in
--                                  normal mode so j/k doesn't reveal each line.
-- Combined, j/k in normal mode triggers no per-move reveal/re-render.
--
-- Colors are re-derived from the ACTIVE colorscheme in apply_render_hl() (runs
-- on every ColorScheme event, so switching Flexoki/Tokyonight/Miasma or
-- Flexoki's light/dark auto-toggle keeps headings in sync). Previously this
-- hardcoded one fixed hex palette regardless of theme/background — that's
-- exactly why headings "didn't match" whenever anything but that one theme
-- was active. Checkbox toggle = bullets.vim's `td`. :RenderMarkdown toggle.

-- Read a highlight group's resolved foreground as "#rrggbb", or nil if the
-- group isn't set (rather than fall back to some other field).
local function resolve_fg(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and hl.fg then return string.format("#%06x", hl.fg) end
  return nil
end

-- Hue in degrees (0-360) via standard RGB->HSL. Used to exclude the whole
-- purple/violet/magenta/pink family (~250°-345°) from headings — an earlier
-- RGB-ratio heuristic here caught magenta but let a borderline purple through
-- (and separately flagged a legitimate teal as "green"), so this checks hue
-- directly instead of guessing from channel comparisons.
local function hue(hex)
  local r = tonumber(hex:sub(2, 3), 16) / 255
  local g = tonumber(hex:sub(4, 5), 16) / 255
  local b = tonumber(hex:sub(6, 7), 16) / 255
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local d = max - min
  if d == 0 then return 0 end
  local h
  if max == r then h = ((g - b) / d) % 6
  elseif max == g then h = (b - r) / d + 2
  else h = (r - g) / d + 4 end
  return h * 60
end

-- Purple/violet/magenta/pink family. Headings shouldn't use these regardless
-- of which theme picks one for a level — Flexoki's own H3 (magenta_two,
-- ~326°) and H1 (purple_two, ~259°) both fall in here, and both got called
-- out as looking bad, so the whole family is excluded, not just true pink.
local function is_pinkish(hex)
  local h = hue(hex)
  return h >= 250 and h <= 345
end

-- Explicit, hand-verified heading palettes for the 3 installed colorschemes
-- (each color pulled from that theme's own real palette module, blue/cyan/
-- green/orange/yellow/red only — the whole purple/magenta/pink family
-- excluded on sight, not detected at runtime). This is deliberately NOT
-- computed from the active colorscheme's own highlight groups at runtime —
-- an earlier version tried that (reading markdownH1..H6 / Title / Function
-- etc. and filtering pink via a hue check) and it kept reportedly still
-- showing pink; hardcoding removes that whole detection path as a variable.
-- Keyed by `colors_name`, then `background`. Flexoki is the only one with a
-- real light variant here — Tokyonight/Miasma are always forced dark by
-- theme.lua (use_tokyonight/use_miasma both set background=dark).
local KNOWN_PALETTES = {
  flexoki = {
    light = { "#205ea6", "#1C6C66", "#bc5215", "#536907", "#8E6B01", "#af3029" },
    dark = { "#4385be", "#3aa99f", "#da702c", "#879a39", "#d0a215", "#d14d41" },
  },
  tokyonight = {
    dark = { "#82aaff", "#86e1fc", "#ff966c", "#c3e88d", "#ffc777", "#ff757f" },
  },
  miasma = {
    dark = { "#b36d43", "#78834b", "#5f875f", "#d7c483" },
  },
}

-- Fallback for any colorscheme not in KNOWN_PALETTES: derive from its own
-- highlight groups at runtime, excluding anything pink/magenta/purple.
local function resolve_fallback_palette()
  local usable = {}
  for i = 1, 6 do
    local c = resolve_fg("markdownH" .. i)
    if c and not is_pinkish(c) then usable[#usable + 1] = c end
  end
  if #usable == 0 then
    for _, name in ipairs({ "Title", "Function", "Type", "Constant", "String", "Special" }) do
      local c = resolve_fg(name)
      if c and not is_pinkish(c) then usable[#usable + 1] = c end
    end
  end
  if #usable == 0 then usable = { "#888888" } end
  return usable
end

local function resolve_heading_palette()
  local by_bg = KNOWN_PALETTES[vim.g.colors_name or ""]
  local usable = (by_bg and (by_bg[vim.o.background] or by_bg.dark or by_bg.light)) or resolve_fallback_palette()
  local palette = {}
  for i = 1, 6 do
    palette[i] = usable[((i - 1) % #usable) + 1]
  end
  -- Explicit overrides on top of the theme-derived base (user preference,
  -- not theme-derived): H1 and H3 swapped, H2 pinned to a fixed green
  -- regardless of theme/light-dark.
  palette[1], palette[3] = palette[3], palette[1]
  palette[2] = "#028A0F"
  return palette
end

local function apply_render_hl()
  -- Headings: theme-derived foreground, no background fill (kills any
  -- colorscheme's heading background wash, pink or otherwise).
  --
  -- RenderMarkdownH{n} alone is NOT enough: it only colors the icon
  -- render-markdown draws (and, via the Bg group, an optional background
  -- wash). The heading TEXT itself is styled separately, by treesitter's
  -- `@markup.heading.{n}.markdown` capture, which Flexoki links straight to
  -- its own `markdownH{n}` (verified live via `:Inspect` — that's genuinely
  -- magenta for H3, independent of anything RenderMarkdownH3 is set to).
  -- Every previous attempt at this only touched RenderMarkdownH{n}, so the
  -- pink text never actually went away. Override markdownH{n} too, to the
  -- same resolved color, so the link target itself changes.
  for i, c in ipairs(resolve_heading_palette()) do
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i, { fg = c, bold = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i .. "Bg", { bg = "NONE" })
    vim.api.nvim_set_hl(0, "markdownH" .. i, { fg = c, bold = true })
  end
  -- Bullets: fixed slate, not bold — deliberately NOT theme-derived (explicit
  -- request), and not bold so smaller/lighter-weight icons (see opts.bullet
  -- below) don't read as heavy. Must be set here, not just in opts, because
  -- render-markdown re-defines RenderMarkdownBullet on attach and would
  -- clobber a highlight set only once at setup time.
  vim.api.nvim_set_hl(0, "RenderMarkdownBulletMuted", { fg = "#535366", bold = false })
end

return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    render_modes = { "n", "c", "t" },
    anti_conceal = { enabled = false },
    win_options = { concealcursor = { rendered = "n" } },
    -- position='inline' (not the plugin default 'overlay'): 'overlay' pads
    -- the icon to fill the raw '#' marker's width, so deeper heading levels
    -- (more '#'s) visually drift further right — an accident of marker
    -- length, not a meaningful indent. That drift reads as inconsistent
    -- against list bullets, which sit at their true source column (flush
    -- left for a top-level list) — a level-3 heading could sit right of a
    -- bullet. 'inline' keeps every heading level's icon flush at the same
    -- column, so indentation only ever reflects real nesting (lists), never
    -- this artifact.
    heading = { sign = false, position = "inline" },
    -- Tables: rendering overlay disabled entirely (explicit request) — tables
    -- display as raw pipe-delimited text. table_mode.lua still owns
    -- realignment/wrapping independent of this.
    pipe_table = { enabled = false },
    -- Bullets: fixed slate (not theme-derived, explicit request), lighter
    -- glyphs than the plugin default (●○◆◇ read as heavy) but not as tiny as
    -- a bare middle dot. Flush at the same column as heading icons (no extra
    -- left_pad) — tried nudging bullets right of headings and it read worse,
    -- not better. Highlight is finalized in apply_render_hl()
    -- (RenderMarkdownBulletMuted), not just here, since render-markdown
    -- re-defines RenderMarkdownBullet on attach.
    bullet = { icons = { "•", "‣", "◦" }, highlight = "RenderMarkdownBulletMuted" },
    -- Checkbox rendering off: several rounds of icon customization never
    -- actually showed up for this user's checkbox lines (root cause still
    -- unconfirmed — plausibly the source isn't in the exact GFM task-item
    -- shape treesitter's grammar requires, e.g. `:Inspect` on one showed
    -- `@markup.link.markdown_inline`, meaning `[ ]`/`[x]` was being parsed as
    -- a link, not a task marker — but unconfirmed). Disabled rather than kept
    -- guessing at icons; raw `[ ]`/`[x]` markdown displays as-is.
    checkbox = { enabled = false },
  },
  config = function(_, opts)
    require("render-markdown").setup(opts)
    apply_render_hl()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_render_hl })
  end,
}
