-- Modal markdown table-of-contents picker built on telescope.nvim.
--
-- `gO` (buffer-local, set in config/autocmds.lua for markdown) opens a fuzzy,
-- j/k-navigable list of the buffer's ATX headings; <CR> jumps to the heading
-- and opens its fold. Replaces Neovim's built-in gO (vim.lsp.buf.document_symbol),
-- which for markdown is a flat, fuzzy-less list and often empty.
--
-- Telescope is lazy-required INSIDE `pick` so this module stays loadable under
-- the repo's headless test harness (tests/run.sh runs with `nvim -u NONE` — no
-- runtime, no plugins). `collect_headings` is a pure function with no telescope
-- dependency, which is what the tests exercise.

local M = {}

-- Is `line` a CommonMark fence opener? 3+ of the same char (``` or ~~~),
-- optionally preceded by up to 3 leading spaces. (Lua patterns have no
-- alternation or {n,m}, so we match the run explicitly.)
local function is_fence(line)
  local t = line:match("^%s*(.-)$")
  local bt = t:match("^(`+)")
  if bt and #bt >= 3 then return true end
  local tl = t:match("^(~+)")
  if tl and #tl >= 3 then return true end
  return false
end

-- Collect ATX headings (1–6 `#`) visible in `buf`, skipping fenced code blocks
-- so a `# comment` inside ```...``` is never mistaken for a heading.
-- Returns { { lnum = 1-based line, level = 1..6, text = "Title" }, ... }.
-- Pure: no telescope, no UI, no side effects — safe under `nvim -u NONE`.
function M.collect_headings(buf)
  buf = buf or 0
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local out = {}
  local in_fence = false

  for i, line in ipairs(lines) do
    if is_fence(line) then
      in_fence = not in_fence
    elseif not in_fence then
      local lead, hashes, rest = line:match("^(%s*)(#+)(.*)$")
      if hashes ~= nil and #hashes >= 1 and #hashes <= 6 then
        -- CommonMark: a space (or EOL) must follow the hashes.
        if rest == "" or rest:sub(1, 1):match("%s") then
          local text = rest:match("^%s*(.-)%s*$") -- trim both ends
          -- Strip a single optional closing-sequence of spaces + hashes
          -- (e.g. "Title ##" -> "Title"), then re-trim.
          text = text:gsub("%s*#+$", "")
          text = text:match("^%s*(.-)%s*$")
          if text ~= "" then
            out[#out + 1] = { lnum = i, level = #hashes, text = text }
          end
        end
      end
    end
  end
  return out
end

-- Open a telescope modal of the buffer's headings.
--   • entries shown indented by heading level; fuzzy match is against the title.
--   • <CR> closes the picker, jumps the cursor to the heading, opens its fold
--     (markdown uses heading-based folding) and centers the line.
--   • j/k and the fuzzy prompt are telescope-native.
function M.pick(opts)
  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local headings = M.collect_headings(0)
  if #headings == 0 then
    vim.notify("No headings found", vim.log.levels.INFO)
    return
  end

  pickers.new(opts, {
    prompt_title = "Table of contents",
    finder = finders.new_table({
      results = headings,
      entry_maker = function(h)
        return {
          value = h.text,
          display = string.rep("  ", h.level - 1) .. h.text,
          ordinal = h.text,
          lnum = h.lnum,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = false,
    layout_strategy = "vertical",
    layout_config = { width = 0.5, height = 0.6 },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          vim.api.nvim_win_set_cursor(0, { entry.lnum, 0 })
          -- Open the fold under the heading (heading-based folding) + center.
          vim.cmd("normal! zvzz")
        end
      end)
      return true
    end,
  }):find()
end

return M
