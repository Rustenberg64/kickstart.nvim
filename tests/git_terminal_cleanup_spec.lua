local this_file = debug.getinfo(1, 'S').source:sub(2)
local tests_dir = vim.fs.dirname(this_file)
local init_path = vim.fs.normalize(vim.fs.joinpath(tests_dir, '..', 'lua', 'custom', 'plugins', 'init.lua'))

local callbacks = {}
local recorded = {
  notify = {},
}
local termopen_result = 77

local original_keymap_set = vim.keymap.set
local original_termopen = vim.fn.termopen
local original_jobwait = vim.fn.jobwait
local original_jobstop = vim.fn.jobstop
local original_notify = vim.notify

vim.keymap.set = function(mode, lhs, rhs, opts)
  if mode == 'n' and (lhs == '<leader>g' or lhs == '<leader>G') then
    callbacks[lhs] = rhs
  end

  return original_keymap_set(mode, lhs, rhs, opts)
end

vim.fn.termopen = function(cmd)
  recorded.termopen_cmd = cmd
  recorded.termopen_buf = vim.api.nvim_get_current_buf()
  recorded.termopen_win = vim.api.nvim_get_current_win()
  return termopen_result
end

vim.fn.jobwait = function(jobs, timeout)
  recorded.jobwait = { jobs = jobs, timeout = timeout }
  return { -1 }
end

vim.fn.jobstop = function(job_id)
  recorded.jobstop = job_id
  return 1
end

vim.notify = function(message, level)
  table.insert(recorded.notify, { message = message, level = level })
end

local function restore()
  vim.keymap.set = original_keymap_set
  vim.fn.termopen = original_termopen
  vim.fn.jobwait = original_jobwait
  vim.fn.jobstop = original_jobstop
  vim.notify = original_notify
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', message, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_truthy(value, message)
  if not value then
    error(message)
  end
end

local ok, err = pcall(dofile, init_path)
if not ok then
  restore()
  error(err)
end

assert_truthy(type(callbacks['<leader>g']) == 'function', 'expected <leader>g mapping callback')
assert_truthy(type(callbacks['<leader>G']) == 'function', 'expected <leader>G mapping callback')

vim.cmd 'enew'

local lazygit_starting_win = vim.api.nvim_get_current_win()

callbacks['<leader>g']()

assert_equal(recorded.termopen_cmd[1], 'lazygit', 'expected lazygit launcher to call termopen')
local lazygit_float_win = vim.api.nvim_get_current_win()
local lazygit_config = vim.api.nvim_win_get_config(lazygit_float_win)

assert_truthy(lazygit_config.relative ~= '', 'expected lazygit to open in a floating window')
assert_equal(recorded.termopen_buf, vim.api.nvim_win_get_buf(lazygit_float_win), 'expected termopen to target the float buffer')
assert_equal(recorded.termopen_win, lazygit_float_win, 'expected lazygit float to be current when termopen runs')

vim.api.nvim_set_current_win(lazygit_starting_win)

assert_equal(recorded.jobstop, 77, 'expected leaving the lazygit float to stop the terminal job')

vim.api.nvim_exec_autocmds('TermClose', { buffer = recorded.termopen_buf })
vim.wait(100, function()
  return not vim.api.nvim_buf_is_valid(recorded.termopen_buf)
    and not vim.api.nvim_win_is_valid(lazygit_float_win)
end)

assert_truthy(not vim.api.nvim_buf_is_valid(recorded.termopen_buf), 'expected lazygit TermClose to wipe the terminal buffer')
assert_truthy(not vim.api.nvim_win_is_valid(lazygit_float_win), 'expected lazygit TermClose to close the float window')
assert_equal(vim.api.nvim_get_current_win(), lazygit_starting_win, 'expected lazygit TermClose to preserve focus on the origin window')

recorded.termopen_cmd = nil
recorded.termopen_buf = nil
recorded.termopen_win = nil
recorded.jobstop = nil
recorded.notify = {}

termopen_result = 0

local lazygit_failure_starting_win = vim.api.nvim_get_current_win()
local lazygit_failure_starting_tab_count = #vim.api.nvim_list_tabpages()

callbacks['<leader>g']()

assert_equal(recorded.termopen_cmd[1], 'lazygit', 'expected lazygit launcher to call termopen on failure path')
local failed_lazygit_float_win = recorded.termopen_win
local failed_lazygit_buf = recorded.termopen_buf

vim.wait(100, function()
  return vim.api.nvim_get_current_win() == lazygit_failure_starting_win
    and not vim.api.nvim_win_is_valid(failed_lazygit_float_win)
    and not vim.api.nvim_buf_is_valid(failed_lazygit_buf)
end)

assert_equal(vim.api.nvim_get_current_win(), lazygit_failure_starting_win, 'expected lazygit launch failure to restore focus')
assert_equal(#vim.api.nvim_list_tabpages(), lazygit_failure_starting_tab_count, 'expected lazygit launch failure to avoid creating tabs')
assert_truthy(not vim.api.nvim_win_is_valid(failed_lazygit_float_win), 'expected lazygit launch failure to close the float window')
assert_truthy(not vim.api.nvim_buf_is_valid(failed_lazygit_buf), 'expected lazygit launch failure to wipe the float buffer')
assert_truthy(#recorded.notify > 0, 'expected lazygit launch failure to notify the user')

termopen_result = 77
recorded.termopen_cmd = nil
recorded.termopen_buf = nil
recorded.termopen_win = nil
recorded.notify = {}

local gitui_starting_tab = vim.api.nvim_get_current_tabpage()
local gitui_starting_tab_count = #vim.api.nvim_list_tabpages()

callbacks['<leader>G']()

assert_equal(recorded.termopen_cmd[1], 'gitui', 'expected gitui launcher to call termopen')
local gitui_float_win = vim.api.nvim_get_current_win()
local gitui_config = vim.api.nvim_win_get_config(gitui_float_win)

assert_truthy(gitui_config.relative == '', 'expected successful gitui launch to stay tab-based')
assert_truthy(vim.api.nvim_get_current_tabpage() ~= gitui_starting_tab, 'expected successful gitui launch to open a new tab')

vim.cmd 'tabprevious'

assert_truthy(vim.api.nvim_get_current_tabpage() == gitui_starting_tab, 'expected successful gitui launch to return to the original tab after tabprevious')

termopen_result = 0
recorded.termopen_cmd = nil
recorded.termopen_buf = nil
recorded.termopen_win = nil

local failed_gitui_starting_tab = vim.api.nvim_get_current_tabpage()
local failed_gitui_starting_tab_count = #vim.api.nvim_list_tabpages()

callbacks['<leader>G']()

assert_equal(recorded.termopen_cmd[1], 'gitui', 'expected gitui launcher to call termopen')
vim.wait(100, function()
  return vim.api.nvim_get_current_tabpage() == failed_gitui_starting_tab
    and #vim.api.nvim_list_tabpages() == failed_gitui_starting_tab_count
    and not vim.api.nvim_buf_is_valid(recorded.termopen_buf)
end)
assert_equal(vim.api.nvim_get_current_tabpage(), failed_gitui_starting_tab, 'expected failed gitui launch to close the created tab')
assert_equal(#vim.api.nvim_list_tabpages(), failed_gitui_starting_tab_count, 'expected failed gitui launch to restore tab count')
assert_truthy(not vim.api.nvim_buf_is_valid(recorded.termopen_buf), 'expected failed gitui launch to wipe the created buffer')
assert_truthy(#recorded.notify > 0, 'expected failed gitui launch to notify the user')

restore()
