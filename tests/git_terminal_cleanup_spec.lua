local this_file = debug.getinfo(1, 'S').source:sub(2)
local tests_dir = vim.fs.dirname(this_file)
local init_path = vim.fs.normalize(vim.fs.joinpath(tests_dir, '..', 'lua', 'custom', 'plugins', 'init.lua'))

local callbacks = {}
local recorded = {
  notify = {},
}
local termopen_result = 77
local termopen_mode = 'pass'
local open_win_mode = 'pass'

local original_keymap_set = vim.keymap.set
local original_open_win = vim.api.nvim_open_win
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

vim.api.nvim_open_win = function(buf, enter, config)
  recorded.open_win = {
    buf = buf,
    enter = enter,
    config = config,
    current_win = vim.api.nvim_get_current_win(),
  }

  if open_win_mode == 'fail' then
    error('simulated nvim_open_win failure')
  end

  return original_open_win(buf, enter, config)
end

vim.fn.termopen = function(cmd)
  if termopen_mode == 'error' then
    error('simulated termopen failure')
  end

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
  vim.api.nvim_open_win = original_open_win
  vim.fn.termopen = original_termopen
  vim.fn.jobwait = original_jobwait
  vim.fn.jobstop = original_jobstop
  vim.notify = original_notify
end

local function reset_records()
  recorded.notify = {}
  recorded.open_win = nil
  recorded.termopen_cmd = nil
  recorded.termopen_buf = nil
  recorded.termopen_win = nil
  recorded.jobwait = nil
  recorded.jobstop = nil
end

local function count_float_windows()
  local count = 0

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= '' then
      count = count + 1
    end
  end

  return count
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

local function launch_lazygit(context)
  callbacks['<leader>g']()

  assert_equal(recorded.termopen_cmd[1], 'lazygit', context .. ' expected lazygit launcher to call termopen')
  local float_win = vim.api.nvim_get_current_win()
  local config = vim.api.nvim_win_get_config(float_win)

  assert_truthy(config.relative ~= '', context .. ' expected lazygit to open in a floating window')
  assert_equal(recorded.termopen_buf, vim.api.nvim_win_get_buf(float_win), context .. ' expected termopen to target the float buffer')
  assert_equal(recorded.termopen_win, float_win, context .. ' expected lazygit float to be current when termopen runs')

  return float_win, recorded.termopen_buf
end

vim.cmd 'enew'

local lazygit_starting_win = vim.api.nvim_get_current_win()

local lazygit_termclose_win, lazygit_termclose_buf = launch_lazygit('direct TermClose')

vim.api.nvim_exec_autocmds('TermClose', { buffer = lazygit_termclose_buf })
vim.wait(100, function()
  return not vim.api.nvim_buf_is_valid(lazygit_termclose_buf)
    and not vim.api.nvim_win_is_valid(lazygit_termclose_win)
end)

assert_truthy(not vim.api.nvim_buf_is_valid(lazygit_termclose_buf), 'expected lazygit TermClose to wipe the terminal buffer')
assert_truthy(not vim.api.nvim_win_is_valid(lazygit_termclose_win), 'expected lazygit TermClose to close the float window')
assert_equal(vim.api.nvim_get_current_win(), lazygit_starting_win, 'expected lazygit TermClose to preserve focus on the origin window')

reset_records()
termopen_result = 77

local lazygit_leave_starting_win = vim.api.nvim_get_current_win()
local lazygit_leave_starting_float_count = count_float_windows()
local lazygit_leave_win, lazygit_leave_buf = launch_lazygit('leave cleanup')

vim.api.nvim_set_current_win(lazygit_leave_starting_win)

assert_equal(recorded.jobstop, 77, 'expected leaving the lazygit float to stop the terminal job')
assert_truthy(not vim.api.nvim_win_is_valid(lazygit_leave_win), 'expected leaving the lazygit float to dismiss the overlay immediately')
assert_truthy(vim.api.nvim_buf_is_valid(lazygit_leave_buf), 'expected leaving the lazygit float to keep the terminal buffer until TermClose')
assert_equal(vim.api.nvim_get_current_win(), lazygit_leave_starting_win, 'expected lazygit leave cleanup to preserve focus on the origin window')
assert_equal(count_float_windows(), lazygit_leave_starting_float_count, 'expected leaving the lazygit float to avoid leaving behind overlay windows')

local lazygit_leave_termclose_ok = pcall(vim.api.nvim_exec_autocmds, 'TermClose', { buffer = lazygit_leave_buf })

assert_truthy(lazygit_leave_termclose_ok, 'expected synthetic TermClose after lazygit leave cleanup to be handled without error')
assert_truthy(not vim.api.nvim_buf_is_valid(lazygit_leave_buf), 'expected synthetic TermClose after lazygit leave cleanup to keep the buffer wiped')
assert_equal(count_float_windows(), lazygit_leave_starting_float_count, 'expected synthetic TermClose after lazygit leave cleanup to not resurrect the float')
assert_equal(vim.api.nvim_get_current_win(), lazygit_leave_starting_win, 'expected synthetic TermClose after lazygit leave cleanup to keep focus on the origin window')

reset_records()
termopen_result = 77
termopen_mode = 'error'

local lazygit_error_starting_win = vim.api.nvim_get_current_win()
local lazygit_error_starting_tab_count = #vim.api.nvim_list_tabpages()
local lazygit_error_starting_float_count = count_float_windows()

local error_ok, error_err = pcall(callbacks['<leader>g'])

assert_truthy(error_ok, 'expected lazygit termopen error to be handled without error')
assert_truthy(recorded.open_win ~= nil, 'expected lazygit termopen error to attempt opening the float')
assert_equal(vim.api.nvim_get_current_win(), lazygit_error_starting_win, 'expected lazygit termopen error to restore focus')
assert_equal(#vim.api.nvim_list_tabpages(), lazygit_error_starting_tab_count, 'expected lazygit termopen error to avoid creating tabs')
assert_equal(count_float_windows(), lazygit_error_starting_float_count, 'expected lazygit termopen error to close the float window')
assert_truthy(not vim.api.nvim_buf_is_valid(recorded.open_win.buf), 'expected lazygit termopen error to wipe the scratch buffer')
assert_truthy(#recorded.notify > 0, 'expected lazygit termopen error to notify the user')

termopen_mode = 'pass'

reset_records()
termopen_result = 77

local lazygit_close_starting_win = vim.api.nvim_get_current_win()
local lazygit_close_win, lazygit_close_buf = launch_lazygit('manual close cleanup')

vim.api.nvim_win_close(lazygit_close_win, true)
vim.wait(100, function()
  return not vim.api.nvim_win_is_valid(lazygit_close_win)
end)

assert_equal(recorded.jobstop, 77, 'expected manually closing the lazygit float to stop the terminal job')
assert_truthy(not vim.api.nvim_win_is_valid(lazygit_close_win), 'expected manually closing the lazygit float to dismiss the overlay')
assert_truthy(vim.api.nvim_buf_is_valid(lazygit_close_buf), 'expected manually closing the lazygit float to keep the terminal buffer until TermClose')
assert_equal(vim.api.nvim_get_current_win(), lazygit_close_starting_win, 'expected lazygit manual close cleanup to preserve focus on the origin window')

vim.api.nvim_exec_autocmds('TermClose', { buffer = lazygit_close_buf })
vim.wait(100, function()
  return not vim.api.nvim_buf_is_valid(lazygit_close_buf)
end)

assert_truthy(not vim.api.nvim_buf_is_valid(lazygit_close_buf), 'expected lazygit manual close TermClose to wipe the terminal buffer')

reset_records()
termopen_result = 77
open_win_mode = 'fail'

local lazygit_failure_starting_win = vim.api.nvim_get_current_win()
local lazygit_failure_starting_tab_count = #vim.api.nvim_list_tabpages()

local open_ok, open_err = pcall(callbacks['<leader>g'])

assert_truthy(open_ok, 'expected lazygit open_win failure to be handled without error')
assert_truthy(recorded.open_win ~= nil, 'expected lazygit open_win failure to attempt opening the float')
assert_truthy(not vim.api.nvim_buf_is_valid(recorded.open_win.buf), 'expected lazygit open_win failure to wipe the scratch buffer')
assert_equal(vim.api.nvim_get_current_win(), lazygit_failure_starting_win, 'expected lazygit open_win failure to restore focus')
assert_equal(#vim.api.nvim_list_tabpages(), lazygit_failure_starting_tab_count, 'expected lazygit open_win failure to avoid creating tabs')
assert_truthy(#recorded.notify > 0, 'expected lazygit open_win failure to notify the user')

open_win_mode = 'pass'
reset_records()
termopen_result = 77

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
assert_equal(recorded.jobstop, 77, 'expected leaving the successful gitui launch to stop the terminal job')

vim.api.nvim_exec_autocmds('TermClose', { buffer = recorded.termopen_buf })
vim.wait(100, function()
  return not vim.api.nvim_buf_is_valid(recorded.termopen_buf)
end)

assert_truthy(not vim.api.nvim_buf_is_valid(recorded.termopen_buf), 'expected successful gitui launch to wipe the created buffer on TermClose')

reset_records()
termopen_result = 0

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

reset_records()
termopen_result = 77
termopen_mode = 'error'

local gitui_error_starting_tab = vim.api.nvim_get_current_tabpage()
local gitui_error_starting_tab_count = #vim.api.nvim_list_tabpages()

local gitui_error_ok, gitui_error_err = pcall(callbacks['<leader>G'])

assert_truthy(gitui_error_ok, 'expected gitui termopen error to be handled without error')
local gitui_error_buf = vim.api.nvim_get_current_buf()

vim.wait(100, function()
  return vim.api.nvim_get_current_tabpage() == gitui_error_starting_tab
    and #vim.api.nvim_list_tabpages() == gitui_error_starting_tab_count
    and not vim.api.nvim_buf_is_valid(gitui_error_buf)
end)

assert_equal(vim.api.nvim_get_current_tabpage(), gitui_error_starting_tab, 'expected gitui termopen error to restore focus to the original tab')
assert_equal(#vim.api.nvim_list_tabpages(), gitui_error_starting_tab_count, 'expected gitui termopen error to avoid leaving an extra tab behind')
assert_truthy(not vim.api.nvim_buf_is_valid(gitui_error_buf), 'expected gitui termopen error to wipe the created buffer')
assert_truthy(#recorded.notify > 0, 'expected gitui termopen error to notify the user')

termopen_mode = 'pass'

restore()
