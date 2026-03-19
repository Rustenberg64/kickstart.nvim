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
  local ok, job_id_or_err = pcall(vim.fn.termopen, cmd)
  local job_id = ok and job_id_or_err or nil

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

local lazygit_state = nil

local function lazygit_float_opts()
  local width = math.max(1, math.min(vim.o.columns, math.max(math.floor(vim.o.columns * 0.9), 80)))
  local height = math.max(1, math.min(vim.o.lines, math.max(math.floor(vim.o.lines * 0.9), 20)))
  local row = math.max(math.floor((vim.o.lines - height) / 2 - 1), 0)
  local col = math.max(math.floor((vim.o.columns - width) / 2), 0)
  return {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
  }
end

local function lazygit_is_alive()
  return lazygit_state
    and lazygit_state.buf
    and vim.api.nvim_buf_is_valid(lazygit_state.buf)
    and type(lazygit_state.job_id) == 'number'
    and lazygit_state.job_id > 0
    and vim.fn.jobwait({ lazygit_state.job_id }, 0)[1] == -1
end

local function lazygit_float_visible()
  if not lazygit_state or not lazygit_state.float_win then
    return false
  end
  if not vim.api.nvim_win_is_valid(lazygit_state.float_win) then
    return false
  end
  local ok, config = pcall(vim.api.nvim_win_get_config, lazygit_state.float_win)
  return ok and not config.hide
end

local function lazygit_cleanup()
  if not lazygit_state then
    return
  end

  local was_visible = lazygit_float_visible()

  local state = lazygit_state
  lazygit_state = nil

  if state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
    pcall(vim.api.nvim_win_close, state.float_win, true)
  end

  if was_visible and state.origin_win and vim.api.nvim_win_is_valid(state.origin_win) then
    pcall(vim.api.nvim_set_current_win, state.origin_win)
  end

  vim.schedule(function()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      pcall(vim.cmd, 'bwipeout! ' .. state.buf)
    end
  end)
end

local function toggle_lazygit()
  -- If float is visible, hide it (keep window + process alive)
  if lazygit_float_visible() then
    pcall(vim.api.nvim_win_set_config, lazygit_state.float_win, { hide = true })
    if lazygit_state.origin_win and vim.api.nvim_win_is_valid(lazygit_state.origin_win) then
      pcall(vim.api.nvim_set_current_win, lazygit_state.origin_win)
    end
    return
  end

  -- If lazygit is alive but hidden, re-show it
  if lazygit_is_alive() then
    lazygit_state.origin_win = vim.api.nvim_get_current_win()
    if lazygit_state.float_win and vim.api.nvim_win_is_valid(lazygit_state.float_win) then
      local opts = lazygit_float_opts()
      opts.hide = false
      local ok = pcall(vim.api.nvim_win_set_config, lazygit_state.float_win, opts)
      if not ok then
        vim.notify('Failed to reopen lazygit window', vim.log.levels.ERROR)
        lazygit_cleanup()
        return
      end
      pcall(vim.api.nvim_set_current_win, lazygit_state.float_win)
    else
      local ok, win = pcall(vim.api.nvim_open_win, lazygit_state.buf, true, lazygit_float_opts())
      if not ok then
        vim.notify('Failed to reopen lazygit window', vim.log.levels.ERROR)
        lazygit_cleanup()
        return
      end
      lazygit_state.float_win = win
    end
    vim.cmd 'startinsert'
    return
  end

  -- Stale state — clean up before fresh start
  if lazygit_state then
    lazygit_cleanup()
  end

  -- Fresh start
  local origin_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false

  local ok_win, float_win = pcall(vim.api.nvim_open_win, buf, true, lazygit_float_opts())
  if not ok_win then
    vim.notify('Failed to launch lazygit', vim.log.levels.ERROR)
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.cmd, 'bwipeout! ' .. buf)
    end
    return
  end

  local ok_job, job_id = pcall(vim.fn.termopen, { 'lazygit' })
  if not ok_job or type(job_id) ~= 'number' or job_id <= 0 then
    vim.notify('Failed to launch lazygit', vim.log.levels.ERROR)
    pcall(vim.api.nvim_win_close, float_win, true)
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.cmd, 'bwipeout! ' .. buf)
    end
    pcall(vim.api.nvim_set_current_win, origin_win)
    return
  end

  lazygit_state = {
    origin_win = origin_win,
    buf = buf,
    float_win = float_win,
    job_id = job_id,
  }

  vim.cmd 'startinsert'

  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    callback = function()
      if not lazygit_state or lazygit_state.buf ~= buf then
        return true
      end
      if lazygit_state.float_win and vim.api.nvim_win_is_valid(lazygit_state.float_win) then
        pcall(vim.api.nvim_win_set_config, lazygit_state.float_win, { hide = true })
      end
    end,
  })

  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function()
      lazygit_cleanup()
    end,
  })
end

-- LazyGit (plugin-free, toggle pattern)
vim.keymap.set('n', '<leader>g', toggle_lazygit, { desc = 'Lazy[G]it' })

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
