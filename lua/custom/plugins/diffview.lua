return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
  keys = {
    { '<leader>do', '<cmd>DiffviewOpen<cr>', desc = '[d]iffview [O]pen' },
    { '<leader>dm', '<cmd>DiffviewOpen<cr>', desc = '[d]iffview [M]odified files' },
    { '<leader>dM', '<cmd>DiffviewOpen main...HEAD --imply-local<cr>', desc = '[d]iffview [M]ain diff' },
    { '<leader>dh', '<cmd>DiffviewFileHistory %<cr>', desc = '[d]iffview file [H]istory' },
    { '<leader>dH', '<cmd>DiffviewFileHistory<cr>', desc = '[d]iffview repo [H]istory' },
    { '<leader>dq', '<cmd>DiffviewClose<cr>', desc = '[d]iffview [Q]uit' },
  },
  opts = {},
}
