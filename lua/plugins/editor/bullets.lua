-- Configure markdown checkbox editing helpers via bullets.vim.
return {
  "bullets-vim/bullets.vim",
  ft = "markdown",
  init = function()
    vim.g.bullets_enabled = true
    vim.g.bullets_set_mappings = false
  end,
  config = function()
    local function split_task_line(line)
      local indent, rest = line:match("^(%s*)(.*)$")
      local marker, body = rest:match("^([%-%*%+]%s+)(.*)$")

      if not marker then
        marker, body = rest:match("^(%d+[%.%)]%s+)(.*)$")
      end

      marker = marker or ""
      body = body or rest or ""
      body = body:gsub("^%[[ xX]%]%s*", "", 1)

      return indent or "", marker, body
    end

    local function enter_insert_after_checkbox(lnum, checkbox_line)
      -- Mode-aware: from insert mode (the Enter mapping) we are already inserting,
      -- so just place the cursor past the trailing space. From normal mode
      -- (ta/to/tO) append with "a" to enter insert mode.
      local mode = vim.api.nvim_get_mode().mode
      if mode == "i" or mode == "R" then
        vim.api.nvim_win_set_cursor(0, { lnum, #checkbox_line })
      else
        vim.api.nvim_win_set_cursor(0, { lnum, math.max(#checkbox_line - 1, 0) })
        vim.api.nvim_feedkeys("a", "n", false)
      end
    end

    local function insert_checkbox(position)
      local row = vim.api.nvim_win_get_cursor(0)[1]
      local current_line = vim.api.nvim_get_current_line()
      local indent, marker, body = split_task_line(current_line)
      local checkbox_line = indent .. marker .. "[ ] "

      -- Keep this line-based: direct fragment insertion tends to break the
      -- space-after-[ ] handoff into insert mode. See tests/markdown_checkbox_mappings.lua.
      if position == "same_line" then
        vim.api.nvim_set_current_line(checkbox_line .. body)
        enter_insert_after_checkbox(row, checkbox_line)
        return
      end

      if position == "below" then
        vim.api.nvim_buf_set_lines(0, row, row, false, { checkbox_line })
        enter_insert_after_checkbox(row + 1, checkbox_line)
        return
      end

      vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { checkbox_line })
      enter_insert_after_checkbox(row, checkbox_line)
    end

    local function toggle_checkbox()
      local line = vim.api.nvim_get_current_line()
      local date = os.date("%Y-%m-%d")

      if line:match("%[ %]") then
        local new_line = line:gsub("%[ %]", "[x]")

        if not new_line:match("%d%d%d%d%-%d%d%-%d%d") then
          if new_line:match("|") then
            new_line = new_line:gsub(" |", " | " .. date .. " |", 1)
          else
            new_line = new_line .. " | " .. date
          end
        end
        vim.api.nvim_set_current_line(new_line)
      else
        local new_line = line:gsub("%[x%]", "[ ]"):gsub("%[X%]", "[ ]")
        -- Remove date stamp added on toggle (e.g. " | 2026-04-02" or " | 2026-04-02 |")
        new_line = new_line:gsub(" | %d%d%d%d%-%d%d%-%d%d |$", "")
        new_line = new_line:gsub(" | %d%d%d%d%-%d%d%-%d%d$", "")
        vim.api.nvim_set_current_line(new_line)
      end
    end

    _G.toggle_checkbox = toggle_checkbox

    -- Detect a markdown task checkbox: `[ ]`, `[x]`, `- [ ]`, `* [X]`, `1. [ ]`, ...
    -- (with or without a leading bullet/number marker).
    local function is_checkbox_line(line)
      local rest = line:match("^%s*(.*)$") or ""
      return rest:match("^%[[ xX]%]") ~= nil
          or rest:match("^[%-%*%+]%s+%[[ xX]%]") ~= nil
          or rest:match("^%d+[%.%)]%s+%[[ xX]%]") ~= nil
    end

    -- Enter on a checkbox line: spawn a fresh unchecked `- [ ] ` below, or — when
    -- the item is empty — exit the list (mirrors bullets.vim for empty items).
    local function continue_checkbox()
      local row = vim.api.nvim_win_get_cursor(0)[1]
      local current = vim.api.nvim_get_current_line()
      local indent, _, body = split_task_line(current)

      if body == "" then
        vim.api.nvim_set_current_line(indent)
        enter_insert_after_checkbox(row, indent)
        return
      end

      insert_checkbox("below")
    end

    _G.markdown_is_checkbox = is_checkbox_line
    _G.markdown_continue_checkbox = continue_checkbox

    local function set_markdown_task_maps(bufnr)
      -- Enter (insert mode): continue a checkbox with a fresh `- [ ] ` below;
      -- otherwise defer to bullets.vim for plain bullets / numbered lists.
      vim.keymap.set("i", "<CR>", function()
        -- Table cells win first (set by markdown_table): moves to the next
        -- cell, or grows the table with a new row at the last cell.
        if _G.markdown_table_enter and _G.markdown_table_enter() then
          return
        end
        if is_checkbox_line(vim.api.nvim_get_current_line()) then
          continue_checkbox()
        else
          vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes("<Plug>(bullets-newline)", true, true, true), "m", false)
        end
      end, { buffer = bufnr, desc = "List — continue checkbox / bullet on Enter" })

      vim.keymap.set("n", "td", toggle_checkbox, { buffer = bufnr, desc = "Toggle checkbox" })

      vim.keymap.set("n", "ta", function()
        insert_checkbox("same_line")
      end, { buffer = bufnr, desc = "New checkbox on current line" })

      vim.keymap.set("n", "to", function()
        insert_checkbox("below")
      end, { buffer = bufnr, desc = "New checkbox below" })

      vim.keymap.set("n", "tO", function()
        insert_checkbox("above")
      end, { buffer = bufnr, desc = "New checkbox above" })

      pcall(vim.keymap.del, "n", "<leader>x", { buffer = bufnr })
      vim.keymap.set("n", "<leader>x", _G.close_current_buffer, {
        buffer = bufnr,
        desc = "Close buffer",
      })
    end

    set_markdown_task_maps(vim.api.nvim_get_current_buf())

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function(args)
        set_markdown_task_maps(args.buf)
      end,
    })
  end,
}
