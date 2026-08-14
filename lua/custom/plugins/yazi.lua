return {
  'mikavilpas/yazi.nvim',
  version = '*',
  event = 'VeryLazy',
  dependencies = {
    { 'nvim-lua/plenary.nvim', lazy = true },
  },
  keys = {
    {
      '<leader>-',
      '<cmd>Yazi<cr>',
      mode = { 'n', 'v' },
      desc = 'Open Yazi at the current file',
    },
  },
  opts = {
    open_for_directories = false,
    open_multiple_tabs = false,
    change_neovim_cwd_on_close = false,
  },
}
