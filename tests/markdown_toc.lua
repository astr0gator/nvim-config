-- Test the markdown TOC picker (config/markdown_toc.lua).
--
-- We exercise the PURE heading extractor (`collect_headings`) — not `pick`,
-- which needs telescope and can't run under the harness (`tests/run.sh` uses
-- `nvim -u NONE`: no runtime, no plugins). `collect_headings` has no telescope
-- dependency and is lazy-required inside `pick`, so the module loads cleanly.
--
-- Covers: ATX levels 1–6, code-fence exclusion (# inside ``` is NOT a heading),
-- trailing closing-hash stripping, the >6-hash non-heading, and the no-space
-- `#tag` non-heading. Pins the behaviours gO relies on so they can't regress.

local cwd = vim.fn.getcwd()
package.path = cwd .. "/lua/?.lua;" .. cwd .. "/lua/?/init.lua;" .. package.path

local toc = require("config.markdown_toc")

local function assert_eq(actual, expected, label)
  if vim.deep_equal(actual, expected) then return end
  error(("%s\nexpected: %s\nactual:   %s"):format(label, vim.inspect(expected), vim.inspect(actual)))
end

assert_eq(type(toc.collect_headings), "function", "collect_headings is a function")
assert_eq(type(toc.pick), "function", "pick is a function")

-- Build a scratch buffer (not in a window — nvim_buf_get_lines still works).
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "# Top Title",          -- 1  h1
  "",                     -- 2
  "Intro text",           -- 3  not a heading
  "",                     -- 4
  "## Section One",       -- 5  h2
  "",                     -- 6
  "```bash",              -- 7  fence open
  "# comment, not heading",-- 8  INSIDE fence — ignored
  "echo hi",              -- 9
  "```",                  -- 10 fence close
  "",                     -- 11
  "### Subsection",       -- 12 h3
  "",                     -- 13
  "## Section Two ##",    -- 14 h2, trailing hashes stripped
  "",                     -- 15
  "####### Too many",     -- 16 7 hashes — not a valid heading
  "",                     -- 17
  "#tag",                 -- 18 no space after # — not a heading
  "",                     -- 19
  "### Deep ### ",        -- 20 h3, trailing hashes stripped
})

local got = toc.collect_headings(buf)
assert_eq(got, {
  { lnum = 1,  level = 1, text = "Top Title" },
  { lnum = 5,  level = 2, text = "Section One" },
  { lnum = 12, level = 3, text = "Subsection" },
  { lnum = 14, level = 2, text = "Section Two" },
  { lnum = 20, level = 3, text = "Deep" },
}, "collect_headings extracts ATX headings, skips fences/>6/no-space")

-- Empty buffer -> no headings.
local empty = vim.api.nvim_create_buf(false, true)
assert_eq(toc.collect_headings(empty), {}, "empty buffer yields no headings")

print("ok: markdown_toc collect_headings picks ATX headings, ignores fences & non-headings")
