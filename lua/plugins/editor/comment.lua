-- Configure Comment.nvim with custom keybindings that fit this keymap setup.
return {
  "numToStr/Comment.nvim",
  event = "VeryLazy",
  opts = function()
    return {
      mappings = { basic = false, extra = false, extended = false },
    }
  end,
  config = function(_, opts)
    require("Comment").setup(opts)

    local comment_api = require("Comment.api")
    local map = vim.keymap.set

    map("n", "<M-/>", function()
      local count = vim.v.count
      if count > 0 then
        comment_api.toggle.linewise.count(count + 1)
      else
        comment_api.toggle.linewise.current()
      end
    end, { desc = "Comment — toggle line" })
    map("v", "<M-/>", "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", { desc = "Comment — toggle selection" })
  end,
}
