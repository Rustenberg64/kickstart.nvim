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
end, { desc = '[Y]ank Relative Path' })

vim.keymap.set({ 'n', 'i', 'v' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Ctrl+[S] Save File' })

vim.keymap.set('n', 'H', '<cmd>bprevious<cr>', { desc = '[H] Previous Buffer' })
vim.keymap.set('n', 'L', '<cmd>bnext<cr>', { desc = '[L] Next Buffer' })

local function open_git_tab_terminal(cmd, label)
  local previous_tab = vim.api.nvim_get_current_tabpage()

  vim.cmd 'noautocmd tabnew'

  local terminal_tab = vim.api.nvim_get_current_tabpage()
  local buf = vim.api.nvim_get_current_buf()
  local job_id = vim.fn.termopen(cmd)

  if type(job_id) ~= 'number' or job_id <= 0 then
    vim.notify('Failed to launch ' .. label, vim.log.levels.ERROR)

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.cmd('bwipeout! ' .. buf)
      end

      if vim.api.nvim_tabpage_is_valid(terminal_tab) then
        pcall(vim.api.nvim_set_current_tabpage, terminal_tab)
        if vim.api.nvim_get_current_tabpage() == terminal_tab then
          vim.cmd 'tabclose!'
        end
      elseif vim.api.nvim_tabpage_is_valid(previous_tab) then
        pcall(vim.api.nvim_set_current_tabpage, previous_tab)
      end
    end)

    return
  end

  vim.cmd 'startinsert'

  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    once = true,
    callback = function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      local status = vim.fn.jobwait({ job_id }, 0)[1]
      if status == -1 then
        vim.fn.jobstop(job_id)
      end
    end,
  })

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
end

local function create_lazygit_float_state()
  local origin_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false

  local width = math.max(math.floor(vim.o.columns * 0.9), 80)
  local height = math.max(math.floor(vim.o.lines * 0.9), 20)
  local row = math.max(math.floor((vim.o.lines - height) / 2 - 1), 0)
  local col = math.max(math.floor((vim.o.columns - width) / 2), 0)

  local state = {
    origin_win = origin_win,
    buf = buf,
    float_win = nil,
    job_id = nil,
    stop_requested = false,
    closed = false,
  }

  local ok, float_win_or_err = pcall(vim.api.nvim_open_win, buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
  })

  if not ok then
    return nil, state, float_win_or_err
  end

  state.float_win = float_win_or_err
  return state
end

local function cleanup_lazygit_float(state, restore_origin)
  if state.closed then
    return
  end

  state.closed = true

  if restore_origin and state.origin_win and vim.api.nvim_win_is_valid(state.origin_win) then
    pcall(vim.api.nvim_set_current_win, state.origin_win)
  end

  if state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
    pcall(vim.api.nvim_win_close, state.float_win, true)
  end

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.cmd, 'bwipeout! ' .. state.buf)
  end
end

local function request_lazygit_stop(state)
  if state.stop_requested or not vim.api.nvim_buf_is_valid(state.buf) or type(state.job_id) ~= 'number' then
    return
  end

  local status = vim.fn.jobwait({ state.job_id }, 0)[1]
  if status == -1 then
    state.stop_requested = true
    vim.fn.jobstop(state.job_id)
  end
end

local function open_lazygit_float()
  local state, failed_state = create_lazygit_float_state()
  if not state then
    vim.notify('Failed to launch lazygit', vim.log.levels.ERROR)
    cleanup_lazygit_float(failed_state, true)
    return
  end

  local ok, job_id_or_err = pcall(vim.fn.termopen, { 'lazygit' })

  if not ok or type(job_id_or_err) ~= 'number' or job_id_or_err <= 0 then
    vim.notify('Failed to launch lazygit', vim.log.levels.ERROR)
    cleanup_lazygit_float(state, true)
    return
  end

  state.job_id = job_id_or_err
  vim.cmd 'startinsert'

  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = state.buf,
    once = true,
    callback = function()
      if state.closed then
        return
      end

      request_lazygit_stop(state)
      cleanup_lazygit_float(state, true)
    end,
  })

  vim.api.nvim_create_autocmd('TermClose', {
    buffer = state.buf,
    once = true,
    callback = function()
      cleanup_lazygit_float(state, true)
    end,
  })
end

-- LazyGit (plugin-free)
vim.keymap.set('n', '<leader>g', function()
  open_lazygit_float()
end, { desc = 'Lazy[G]it' })

-- GitUI (plugin-free)
vim.keymap.set('n', '<leader>G', function()
  open_git_tab_terminal({ 'gitui' }, 'gitui')
end, { desc = '[G]itUI' })

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
