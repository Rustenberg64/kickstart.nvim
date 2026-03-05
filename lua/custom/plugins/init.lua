-- Custom options
vim.env.PATH = vim.env.HOME .. '/.asdf/shims:' .. vim.env.PATH
vim.opt.synmaxcol = 240
vim.opt.updatetime = 200
vim.opt.redrawtime = 1500

-- Keymaps
vim.keymap.set('n', '<leader>y', function()
  local path = vim.fn.fnamemodify(vim.fn.expand '%:p', ':~:.')
  vim.fn.setreg('+', path)
  print('Copied: ' .. path)
end, { desc = 'Copy relative path' })

-- Autocmds: terminal mode tmux navigation
vim.api.nvim_create_autocmd('TermOpen', {
  callback = function()
    local opts = { buffer = 0 }
    vim.keymap.set('t', '<C-h>', '<C-\\><C-n><cmd>TmuxNavigateLeft<cr>', opts)
    vim.keymap.set('t', '<C-j>', '<C-\\><C-n><cmd>TmuxNavigateDown<cr>', opts)
    vim.keymap.set('t', '<C-k>', '<C-\\><C-n><cmd>TmuxNavigateUp<cr>', opts)
    vim.keymap.set('t', '<C-l>', '<C-\\><C-n><cmd>TmuxNavigateRight<cr>', opts)
  end,
})

return {}
