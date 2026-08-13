return {
  'pwntester/octo.nvim',
  cmd = 'Octo',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  keys = {
    { '<leader>oi', '<cmd>Octo issue list<cr>', desc = '[O]cto [I]ssue list' },
    { '<leader>op', '<cmd>Octo pr list<cr>', desc = '[O]cto [P]R list' },
    {
      '<leader>os',
      function() require('octo.utils').create_base_search_command { include_current_repo = true } end,
      desc = '[O]cto [S]earch',
    },
  },
  opts = {
    picker = 'telescope',
    enable_builtin = true,
  },
}
