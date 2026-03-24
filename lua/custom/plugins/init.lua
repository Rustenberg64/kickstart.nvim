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

-- Shared git float terminal infrastructure

local function git_float_opts()
  local width = math.max(1, math.min(vim.o.columns, math.max(math.floor(vim.o.columns * 0.98), 80)))
  local height = math.max(1, math.min(vim.o.lines, math.max(math.floor(vim.o.lines * 0.98), 20)))
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

local function float_is_alive(state)
  return state
    and state.buf
    and vim.api.nvim_buf_is_valid(state.buf)
    and type(state.job_id) == 'number'
    and state.job_id > 0
    and vim.fn.jobwait({ state.job_id }, 0)[1] == -1
end

local function float_visible(state)
  if not state or not state.float_win then
    return false
  end
  if not vim.api.nvim_win_is_valid(state.float_win) then
    return false
  end
  local ok, config = pcall(vim.api.nvim_win_get_config, state.float_win)
  return ok and not config.hide
end

local function cleanup_git_float(state)
  if not state then
    return
  end

  local was_visible = float_visible(state)

  if state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
    pcall(vim.api.nvim_win_close, state.float_win, true)
  end

  if was_visible and state.origin_win and vim.api.nvim_win_is_valid(state.origin_win) then
    pcall(vim.api.nvim_set_current_win, state.origin_win)
  end

  if state.on_cleanup then
    state.on_cleanup()
  end

  vim.schedule(function()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      pcall(vim.cmd, 'bwipeout! ' .. state.buf)
    end
  end)
end

-- Toggle a git TUI float terminal. `cmd` and `opts.on_cleanup` are only used
-- when creating a fresh instance (not during hide/show toggle).
local function toggle_git_float(state, cmd, opts)
  opts = opts or {}
  local label = cmd[#cmd]

  -- If float is visible, hide it (keep window + process alive)
  if float_visible(state) then
    pcall(vim.api.nvim_win_set_config, state.float_win, { hide = true })
    if state.origin_win and vim.api.nvim_win_is_valid(state.origin_win) then
      pcall(vim.api.nvim_set_current_win, state.origin_win)
    end
    return state
  end

  -- If alive but hidden, re-show it
  if float_is_alive(state) then
    state.origin_win = vim.api.nvim_get_current_win()
    if state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
      local fopts = git_float_opts()
      fopts.hide = false
      local ok = pcall(vim.api.nvim_win_set_config, state.float_win, fopts)
      if not ok then
        vim.notify('Failed to reopen ' .. label .. ' window', vim.log.levels.ERROR)
        cleanup_git_float(state)
        if opts.set_state then opts.set_state(nil) end
        return nil
      end
      pcall(vim.api.nvim_set_current_win, state.float_win)
    else
      local ok, win = pcall(vim.api.nvim_open_win, state.buf, true, git_float_opts())
      if not ok then
        vim.notify('Failed to reopen ' .. label .. ' window', vim.log.levels.ERROR)
        cleanup_git_float(state)
        if opts.set_state then opts.set_state(nil) end
        return nil
      end
      state.float_win = win
    end
    vim.cmd 'startinsert'
    return state
  end

  -- Stale state — clean up before fresh start
  if state then
    cleanup_git_float(state)
    if opts.set_state then opts.set_state(nil) end
  end

  -- Fresh start
  local origin_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false

  local ok_win, float_win = pcall(vim.api.nvim_open_win, buf, true, git_float_opts())
  if not ok_win then
    vim.notify('Failed to launch ' .. label, vim.log.levels.ERROR)
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.cmd, 'bwipeout! ' .. buf)
    end
    if opts.on_cleanup then opts.on_cleanup() end
    return nil
  end

  local ok_job, job_id = pcall(vim.fn.termopen, cmd)
  if not ok_job or type(job_id) ~= 'number' or job_id <= 0 then
    vim.notify('Failed to launch ' .. label, vim.log.levels.ERROR)
    pcall(vim.api.nvim_win_close, float_win, true)
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.cmd, 'bwipeout! ' .. buf)
    end
    pcall(vim.api.nvim_set_current_win, origin_win)
    if opts.on_cleanup then opts.on_cleanup() end
    return nil
  end

  local new_state = {
    origin_win = origin_win,
    buf = buf,
    float_win = float_win,
    job_id = job_id,
    on_cleanup = opts.on_cleanup,
  }

  vim.cmd 'startinsert'

  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    callback = function()
      if not vim.api.nvim_win_is_valid(float_win) then
        return true
      end
      pcall(vim.api.nvim_win_set_config, float_win, { hide = true })
    end,
  })

  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function()
      cleanup_git_float(new_state)
      if opts.set_state then opts.set_state(nil) end
    end,
  })

  return new_state
end

local function make_gitui_cmd()
  local servername = vim.v.servername
  if not servername or servername == '' then
    return { 'gitui' }, nil
  end

  local script_path = vim.fn.tempname() .. '.sh'
  vim.fn.writefile({
    '#!/usr/bin/env bash',
    'nvim --server ' .. vim.fn.shellescape(servername) .. ' --remote-send "<Cmd>lua _G._gitui_remote_edit([[$(realpath "$1")]])<CR>"',
  }, script_path)
  vim.fn.setfperm(script_path, 'rwxr-xr-x')

  local cmd = { 'env', 'EDITOR=' .. script_path, 'gitui' }
  local on_cleanup = function()
    pcall(os.remove, script_path)
  end

  return cmd, on_cleanup
end

local lazygit_state = nil
local gitui_state = nil

-- Open a file from gitui's edit_file in the origin window (not the float)
_G._gitui_remote_edit = function(file)
  if gitui_state and gitui_state.origin_win and vim.api.nvim_win_is_valid(gitui_state.origin_win) then
    pcall(vim.api.nvim_set_current_win, gitui_state.origin_win)
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(file))
end

-- LazyGit (plugin-free, toggle pattern)
vim.keymap.set('n', '<leader>g', function()
  lazygit_state = toggle_git_float(lazygit_state, { 'lazygit' }, {
    set_state = function(s) lazygit_state = s end,
  })
end, { desc = 'Lazy[g]it' })

-- GitUI (plugin-free, float + nvim remote)
vim.keymap.set('n', '<leader>G', function()
  local cmd, on_cleanup
  if not float_is_alive(gitui_state) then
    cmd, on_cleanup = make_gitui_cmd()
  else
    cmd = { 'gitui' }
  end
  gitui_state = toggle_git_float(gitui_state, cmd, {
    on_cleanup = on_cleanup,
    set_state = function(s) gitui_state = s end,
  })
end, { desc = '[G]itUI (shift)' })

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
