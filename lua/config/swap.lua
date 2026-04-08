-- Swap register: grab a value, move to another, swap them.
--
-- Usage:
--   <leader>ps  first call: grabs the node/value under cursor
--              second call: swaps it with the node/value under cursor now

local M = {}

local state = {
  text = nil,    -- saved text
  pos = nil,     -- saved position {buf, row, col}
  node_range = nil, -- saved node range {start_row, start_col, end_row, end_col}
}

-- Get the smallest meaningful Tree-sitter node at cursor
local function get_node_at_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1

  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local root = tree:root()
  local node = root:named_descendant_for_range(row, col, row, col)
  if not node then
    return nil
  end

  -- Walk up to find a "value-like" node (skip identifiers, keys, punctuation)
  -- Prefer leaf-ish nodes that represent actual values
  local current = node
  while current do
    local type = current:type()
    -- JSON/literal value types
    if type == "number"
      or type == "string"
      or type == "true"
      or type == "false"
      or type == "null"
      -- Generic value types
      or type == "string_content"
      or type == "string_fragment"
      -- Identifier that could be a value
      or type == "identifier"
      or type == "integer"
      or type == "float"
      or type == "boolean"
    then
      -- If parent is a pair/property, grab just the value child, not the key
      local parent = current:parent()
      if parent then
        local ptype = parent:type()
        if ptype == "pair" or ptype == "property" or ptype == "field_value" then
          -- Return the value portion only (last named child of pair)
          local children = parent:named_children()
          if #children >= 2 then
            return children[#children]
          end
        end
      end
      return current
    end
    current = current:parent()
  end

  -- Fallback: return the leaf node we found
  return node
end

-- Get text of a node
local function get_node_text(buf, node)
  local s_row, s_col = node:start()
  local e_row, e_col = node:end_()
  local lines = vim.api.nvim_buf_get_text(buf, s_row, s_col, e_row, e_col, {})
  return table.concat(lines, "\n")
end

-- Replace node text in buffer
local function set_node_text(buf, node, text)
  local s_row, s_col = node:start()
  local e_row, e_col = node:end_()
  local replacement = vim.split(text, "\n")
  vim.api.nvim_buf_set_text(buf, s_row, s_col, e_row, e_col, replacement)
end

-- Fallback: grab/swap the word under cursor (no Tree-sitter)
local function get_word_range()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  -- Find word boundaries
  local left = col
  while left > 0 and line:sub(left, left):match("[%w_]") do
    left = left - 1
  end
  local right = col + 1
  while right <= #line and line:sub(right, right):match("[%w_]") do
    right = right + 1
  end

  -- Include surrounding quotes if present
  if left >= 1 and line:sub(left, left) == '"' then left = left - 1 end
  if right <= #line and line:sub(right, right) == '"' then right = right + 1 end

  local text = line:sub(left + 1, right - 1)
  return text, row - 1, left, right - 1
end

function M.swap()
  local buf = vim.api.nvim_get_current_buf()

  -- SECOND call: swap
  if state.text and state.pos then
    -- Get current target
    local cur_node = get_node_at_cursor()

    if cur_node and state.node_range then
      -- Tree-sitter swap
      local cur_text = get_node_text(buf, cur_node)

      -- Need to adjust the saved node position if buffer shifted
      set_node_text(buf, cur_node, state.text)

      -- Now replace saved node
      local sr, sc, er, ec = unpack(state.node_range)
      local replacement = vim.split(cur_text, "\n")
      vim.api.nvim_buf_set_text(buf, sr, sc, er, ec, replacement)

      vim.notify("Swapped!", vim.log.levels.INFO)
    else
      -- Fallback word swap
      local cur_text, cur_row, cur_left, cur_right = get_word_range()

      -- Replace current word with saved
      local line = vim.api.nvim_buf_get_lines(buf, cur_row, cur_row + 1, false)[1]
      local before = line:sub(1, cur_left)
      local after = line:sub(cur_right + 1)
      local new_line = before .. state.text .. after
      vim.api.nvim_buf_set_lines(buf, cur_row, cur_row + 1, false, { new_line })

      -- Replace saved word with current
      local s_row = state.pos[2]
      local saved_line = vim.api.nvim_buf_get_lines(buf, s_row, s_row + 1, false)[1]
      local s_left = state.pos[3]
      local s_right = state.pos[4]
      local s_before = saved_line:sub(1, s_left)
      local s_after = saved_line:sub(s_right + 1)
      local s_new_line = s_before .. cur_text .. s_after
      vim.api.nvim_buf_set_lines(buf, s_row, s_row + 1, false, { s_new_line })

      vim.notify("Swapped!", vim.log.levels.INFO)
    end

    -- Reset state
    state.text = nil
    state.pos = nil
    state.node_range = nil
    return
  end

  -- FIRST call: grab value
  local node = get_node_at_cursor()
  if node then
    local text = get_node_text(buf, node)
    local sr, sc = node:start()
    local er, ec = node:end_()
    state.text = text
    state.node_range = { sr, sc, er, ec }
    state.pos = { buf, sr, sc, ec }
    vim.notify("Grabbed: " .. text, vim.log.levels.INFO)
  else
    -- Fallback to word
    local text, row, left, right = get_word_range()
    state.text = text
    state.node_range = nil
    state.pos = { buf, row, left, right }
    vim.notify("Grabbed: " .. text, vim.log.levels.INFO)
  end
end

-- Cancel a pending swap
function M.cancel()
  if state.text then
    state.text = nil
    state.pos = nil
    state.node_range = nil
    vim.notify("Swap cancelled", vim.log.levels.INFO)
  end
end

return M
