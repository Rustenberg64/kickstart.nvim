return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
  keys = {
    { '<leader>do', '<cmd>DiffviewOpen<cr>', desc = '[D]iffview [O]pen' },
    { '<leader>dm', '<cmd>DiffviewOpen<cr>', desc = '[D]iffview [M]odified Files' },
    { '<leader>dM', '<cmd>DiffviewOpen main...HEAD --imply-local<cr>', desc = '[D]iffview [M]ain Diff' },
    { '<leader>dh', '<cmd>DiffviewFileHistory %<cr>', desc = '[D]iffview File [H]istory' },
    { '<leader>dH', '<cmd>DiffviewFileHistory<cr>', desc = '[D]iffview Repo [H]istory' },
    { '<leader>dq', '<cmd>DiffviewClose<cr>', desc = '[D]iffview [Q]uit' },
  },
  opts = {},
}
