-- Pin the smooth-scroll keymaps so the j/k + <C-j>/<C-k> speed & routing never
-- regress. <C-j>/<C-k> MUST map to <C-d>/<C-u> with remap=true so they route
-- THROUGH neoscroll.nvim (the smooth half-page animation). Switching them to
-- noremap or a raw line count snaps instantly and silently kills the animation.
-- <A-j>/<A-k> are the noremap half-page jumps that re-center (zz). We load the
-- REAL keymaps.lua (its requires are lazy/in-callback, so dofile is safe), not
-- a mirror copy, so this catches actual regressions in the config.

local cwd = vim.fn.getcwd()
package.path = cwd .. "/lua/?.lua;" .. cwd .. "/lua/?/init.lua;" .. package.path
dofile(cwd .. "/lua/config/keymaps.lua")

local function assert_eq(actual, expected, label)
  if vim.deep_equal(actual, expected) then return end
  error(("%s\nexpected: %s\nactual:   %s"):format(label, vim.inspect(expected), vim.inspect(actual)))
end

-- j / k must stay pristine: no plugin (markview included) may rebind them.
assert_eq(vim.fn.maparg("j", "n"), "", "j must not be remapped")
assert_eq(vim.fn.maparg("k", "n"), "", "k must not be remapped")

-- Does a mapping's rhs route through the given key (e.g. <C-d>)? maparg returns
-- rhs in key notation (often upper, e.g. "<C-D>"), so compare case-insensitively
-- and literally (plain find — no pattern escaping).
local function routes_to(info, want) -- want is lowercase notation, e.g. "<c-d>"
  return (info.rhs or ""):lower():find(want, 1, true) ~= nil
end

-- <C-j>/<C-k> route to neoscroll via <C-d>/<C-u> with remap=true (noremap==0).
local cjd = vim.fn.maparg("<C-j>", "n", false, true)
assert_eq(cjd.rhs ~= "", true, "<C-j> must be mapped")
assert_eq(cjd.noremap, 0, "<C-j> must be remap=true (routes through neoscroll, not raw)")
assert_eq(routes_to(cjd, "<c-d>"), true, "<C-j> rhs routes via <C-d> (got " .. vim.inspect(cjd.rhs) .. ")")

local cku = vim.fn.maparg("<C-k>", "n", false, true)
assert_eq(cku.rhs ~= "", true, "<C-k> must be mapped")
assert_eq(cku.noremap, 0, "<C-k> must be remap=true (routes through neoscroll, not raw)")
assert_eq(routes_to(cku, "<c-u>"), true, "<C-k> rhs routes via <C-u> (got " .. vim.inspect(cku.rhs) .. ")")

-- <A-j>/<A-k> = half-page jump that re-centers (noremap, ends in zz).
local ajd = vim.fn.maparg("<A-j>", "n", false, true)
assert_eq(ajd.noremap, 1, "<A-j> must be noremap")
assert_eq(routes_to(ajd, "<c-d>zz"), true, "<A-j> rhs = <C-d>zz (got " .. vim.inspect(ajd.rhs) .. ")")
local aku = vim.fn.maparg("<A-k>", "n", false, true)
assert_eq(aku.noremap, 1, "<A-k> must be noremap")
assert_eq(routes_to(aku, "<c-u>zz"), true, "<A-k> rhs = <C-u>zz (got " .. vim.inspect(aku.rhs) .. ")")

print("ok: smooth-scroll keymap tests passed (j/k pristine, <C-j>/<C-k> neoscroll routing)")
