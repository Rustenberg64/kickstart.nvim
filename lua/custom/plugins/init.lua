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

vim.keymap.set({ 'n', 'i', 'v' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save file' })

vim.keymap.set('n', 'H', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
vim.keymap.set('n', 'L', '<cmd>bnext<cr>', { desc = 'Next buffer' })

-- LazyGit (plugin-free)
vim.keymap.set('n', '<leader>g', function()
  vim.cmd 'noautocmd tabnew'
  local buf = vim.api.nvim_get_current_buf()
  vim.fn.termopen({ 'lazygit' })
  vim.cmd 'startinsert'
  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.cmd('bwipeout! ' .. buf)
        end
      end)
    end,
  })
end, { desc = 'LazyGit' })

-- Autocmds: terminal mode
vim.api.nvim_create_autocmd('TermOpen', {
  callback = function()
    local opts = { buffer = 0 }
    vim.keymap.set('t', '<C-h>', '<C-\\><C-n><cmd>TmuxNavigateLeft<cr>', opts)
    vim.keymap.set('t', '<C-j>', '<C-\\><C-n><cmd>TmuxNavigateDown<cr>', opts)
    vim.keymap.set('t', '<C-k>', '<C-\\><C-n><cmd>TmuxNavigateUp<cr>', opts)
    vim.keymap.set('t', '<C-l>', '<C-\\><C-n><cmd>TmuxNavigateRight<cr>', opts)
  end,
})

-- Auto-enter insert mode when returning to a terminal buffer
vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained' }, {
  callback = function()
    if vim.bo.buftype == 'terminal' and vim.fn.mode() == 'n' then
      vim.cmd 'startinsert'
    end
  end,
})

return {}
