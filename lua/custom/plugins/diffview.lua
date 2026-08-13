local function review_base()
  local out = vim.fn.systemlist 'git symbolic-ref --short refs/remotes/origin/HEAD'
  if vim.v.shell_error == 0 and out[1] and out[1] ~= '' then return out[1] end
  for _, ref in ipairs { 'origin/main', 'origin/master' } do
    vim.fn.system('git rev-parse --verify --quiet ' .. ref)
    if vim.v.shell_error == 0 then return ref end
  end
  return 'main'
end

return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
  keys = {
    { '<leader>do', '<cmd>DiffviewOpen<cr>', desc = '[D]iffview [O]pen (working tree)' },
    {
      '<leader>dm',
      function() vim.cmd('DiffviewOpen ' .. review_base() .. '...HEAD --imply-local') end,
      desc = '[D]iffview [M]erge-base diff (PR review)',
    },
    { '<leader>dh', '<cmd>DiffviewFileHistory %<cr>', desc = '[D]iffview File [H]istory' },
    { '<leader>dH', '<cmd>DiffviewFileHistory<cr>', desc = '[D]iffview Repo [H]istory' },
    { '<leader>dq', '<cmd>DiffviewClose<cr>', desc = '[D]iffview [Q]uit' },
  },
  opts = function()
    local actions = require 'diffview.actions'
    return {
      enhanced_diff_hl = true,
      view = {
        default = { winbar_info = true },
        file_history = { winbar_info = true },
      },
      keymaps = {
        view = {
          { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close diffview' } },
          { 'n', ']f', actions.select_next_entry, { desc = 'Next file' } },
          { 'n', '[f', actions.select_prev_entry, { desc = 'Prev file' } },
        },
        file_panel = {
          { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close diffview' } },
          { 'n', ']f', actions.select_next_entry, { desc = 'Next file' } },
          { 'n', '[f', actions.select_prev_entry, { desc = 'Prev file' } },
        },
        file_history_panel = {
          { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close diffview' } },
        },
      },
    }
  end,
}
