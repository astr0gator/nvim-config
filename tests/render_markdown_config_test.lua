-- Pin render-markdown.nvim's scroll-friendly config so the j/k + <C-j>/<C-k>
-- regressions can't silently come back. With render_modes including insert OR
-- anti_conceal on, j/k in normal mode re-renders / reveals each line — exactly
-- the markview problem we abandoned render-markdown-for before. If this test
-- fails, do NOT silence it: re-adding insert to render_modes or enabling
-- anti_conceal reintroduces the scroll/edit-view lag.

local spec = dofile(vim.fn.getcwd() .. "/lua/plugins/ui/render_markdown.lua")

local function assert_eq(actual, expected, label)
  if vim.deep_equal(actual, expected) then return end
  error(("%s\nexpected: %s\nactual:   %s"):format(label, vim.inspect(expected), vim.inspect(actual)))
end

-- Lazy-loaded on markdown (safe for render-markdown; keeps startup fast).
assert_eq(vim.list_contains(spec.ft, "markdown"), true, "must lazy-load on markdown")

-- Render in normal/command/terminal ONLY — not insert. Insert = raw text, so no
-- re-render while typing and raw text appears only after pressing i.
assert_eq(vim.list_contains(spec.opts.render_modes, "n"), true, "render_modes must include n")
assert_eq(vim.list_contains(spec.opts.render_modes, "i"), false,
  "render_modes must NOT include i (would re-render while typing)")

-- anti_conceal OFF: normal-mode j/k must NOT reveal the cursor line as raw.
assert_eq(spec.opts.anti_conceal.enabled, false,
  "anti_conceal must be disabled (else j/k flips each line into raw view)")

-- concealcursor rendered="n": keep conceal active on the cursor line in normal
-- mode so j/k doesn't reveal it (the default "" reveals the cursor line raw).
assert_eq(spec.opts.win_options.concealcursor.rendered, "n",
  "concealcursor rendered must be 'n' (cursor line stays rendered in normal mode)")

-- Pipe tables: render-markdown draws the box-drawing borders; table_mode.lua
-- owns realignment/wrapping and sizes columns using RENDERED (concealed)
-- width, with slack budgeted for markup that disappears on render (backticks,
-- **bold**, etc.) — see cellwidth()/strip_concealed() in table_mode.lua. That
-- keeps table_mode's physical wrapping and render-markdown's border overlay
-- in agreement even for wide, multi-column, wrapped tables (verified live).
-- An earlier "borders jump" finding here was a render-timing race (captured
-- mid-redraw right after the on-open auto-realign), not a real conflict.
assert_eq(spec.opts.pipe_table.enabled, true,
  "pipe tables should render with box-drawing borders; table_mode.lua keeps column math render-aware")

print("ok: render-markdown config invariants hold (render_modes={n,c,t}, anti_conceal off, markdown ft)")
