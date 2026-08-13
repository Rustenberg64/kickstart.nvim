return {
  'keaising/im-select.nvim',
  event = 'VimEnter',
  config = function() require('im_select').setup {} end,
}
