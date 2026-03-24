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
local jobwait_result = { -1 }

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

vim.fn.termopen = function(cmd, opts)
  if termopen_mode == 'error' then
    error('simulated termopen failure')
  end

  if termopen_mode == 'real_async' and type(cmd) == 'table' and (cmd[1] == 'lazygit' or vim.tbl_contains(cmd, 'gitui')) then
    recorded.termopen_cmd = cmd
    recorded.termopen_opts = opts
    recorded.termopen_buf = vim.api.nvim_get_current_buf()
    recorded.termopen_win = vim.api.nvim_get_current_win()
    return original_termopen({ 'sh', '-c', 'exit 0' })
  end

  recorded.termopen_cmd = cmd
  recorded.termopen_opts = opts
  recorded.termopen_buf = vim.api.nvim_get_current_buf()
  recorded.termopen_win = vim.api.nvim_get_current_win()
  return termopen_result
end

vim.fn.jobwait = function(jobs, timeout)
  recorded.jobwait = { jobs = jobs, timeout = timeout }
  return jobwait_result
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
  recorded.termopen_opts = nil
  recorded.termopen_buf = nil
  recorded.termopen_win = nil
  recorded.jobwait = nil
  recorded.jobstop = nil
end

local function count_float_windows()
  local count = 0

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= '' and not config.hide then
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

local function assert_win_hidden(win, message)
  assert_truthy(vim.api.nvim_win_is_valid(win), message .. ' (window invalid)')
  local ok, config = pcall(vim.api.nvim_win_get_config, win)
  assert_truthy(ok and config.hide, message)
end

-- Ensure vim.v.servername is set so make_gitui_cmd() creates the nvim remote
-- script. In headless -u NONE mode, servername is empty by default.
if vim.v.servername == '' then
  local test_server = vim.fn.tempname() .. '-test-server'
  vim.fn.serverstart(test_server)
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

local function launch_gitui(context)
  callbacks['<leader>G']()

  assert_truthy(
    vim.tbl_contains(recorded.termopen_cmd, 'gitui'),
    context .. ' expected gitui launcher to call termopen with gitui in cmd'
  )
  local float_win = vim.api.nvim_get_current_win()
  local config = vim.api.nvim_win_get_config(float_win)

  assert_truthy(config.relative ~= '', context .. ' expected gitui to open in a floating window')
  assert_equal(recorded.termopen_buf, vim.api.nvim_win_get_buf(float_win), context .. ' expected termopen to target the float buffer')

  return float_win, recorded.termopen_buf
end

local test_ok, test_err = pcall(function()
  vim.cmd 'enew'

  -- == Test 1: Direct TermClose (lazygit quits normally) ==

  local lazygit_starting_win = vim.api.nvim_get_current_win()
  local lazygit_starting_tab = vim.api.nvim_get_current_tabpage()

  local lazygit_termclose_win, lazygit_termclose_buf = launch_lazygit('direct TermClose')

  assert_equal(vim.api.nvim_get_current_tabpage(), lazygit_starting_tab, 'expected lazygit to stay in the current tab while floating')

  vim.api.nvim_exec_autocmds('TermClose', { buffer = lazygit_termclose_buf })
  vim.wait(100, function()
    return not vim.api.nvim_buf_is_valid(lazygit_termclose_buf)
      and not vim.api.nvim_win_is_valid(lazygit_termclose_win)
  end)

  assert_truthy(not vim.api.nvim_buf_is_valid(lazygit_termclose_buf), 'expected lazygit TermClose to wipe the terminal buffer')
  assert_truthy(not vim.api.nvim_win_is_valid(lazygit_termclose_win), 'expected lazygit TermClose to close the float window')
  assert_equal(vim.api.nvim_get_current_win(), lazygit_starting_win, 'expected lazygit TermClose to preserve focus on the origin window')

  -- == Test 2: Geometry clamping ==

  local lazygit_geometry_columns = vim.o.columns
  local lazygit_geometry_lines = vim.o.lines
  local lazygit_geometry_test_columns = math.max(1, math.min(lazygit_geometry_columns, 70))
  local lazygit_geometry_test_lines = math.max(1, math.min(lazygit_geometry_lines, 18))

  vim.o.columns = lazygit_geometry_test_columns
  vim.o.lines = lazygit_geometry_test_lines

  local lazygit_geometry_ok, lazygit_geometry_err = pcall(function()
    reset_records()
    termopen_result = 77

    local lazygit_geometry_win, lazygit_geometry_buf = launch_lazygit('geometry clamp')
    local lazygit_geometry_config = recorded.open_win.config

    assert_truthy(
      lazygit_geometry_config.width <= lazygit_geometry_test_columns,
      'expected lazygit float width to stay within the current editor columns'
    )
    assert_truthy(
      lazygit_geometry_config.height <= lazygit_geometry_test_lines,
      'expected lazygit float height to stay within the current editor lines'
    )

    vim.api.nvim_exec_autocmds('TermClose', { buffer = lazygit_geometry_buf })
    vim.wait(100, function()
      return not vim.api.nvim_buf_is_valid(lazygit_geometry_buf) and not vim.api.nvim_win_is_valid(lazygit_geometry_win)
    end)

    assert_truthy(
      not vim.api.nvim_buf_is_valid(lazygit_geometry_buf),
      'expected lazygit geometry clamp cleanup to wipe the terminal buffer'
    )
    assert_truthy(
      not vim.api.nvim_win_is_valid(lazygit_geometry_win),
      'expected lazygit geometry clamp cleanup to close the float window'
    )
  end)

  vim.o.columns = lazygit_geometry_columns
  vim.o.lines = lazygit_geometry_lines

  assert_truthy(lazygit_geometry_ok, lazygit_geometry_err)

  -- == Test 3: Toggle hide/show cycle ==

  reset_records()
  termopen_result = 77

  local toggle_starting_win = vim.api.nvim_get_current_win()
  local toggle_starting_float_count = count_float_windows()

  local toggle_float_win, toggle_buf = launch_lazygit('toggle open')

  -- Toggle hide: <leader>g while float is visible
  reset_records()
  callbacks['<leader>g']()

  assert_win_hidden(toggle_float_win, 'expected toggle hide to hide the float window')
  assert_truthy(vim.api.nvim_buf_is_valid(toggle_buf), 'expected toggle hide to keep the buffer alive')
  assert_equal(recorded.jobstop, nil, 'expected toggle hide to NOT stop the job')
  assert_equal(count_float_windows(), toggle_starting_float_count, 'expected toggle hide to have no visible float windows')

  -- Toggle show: <leader>g while hidden (should reuse same window, no new termopen)
  reset_records()
  callbacks['<leader>g']()

  assert_equal(vim.api.nvim_get_current_win(), toggle_float_win, 'expected toggle show to reuse the same window')
  assert_truthy(not vim.api.nvim_win_get_config(toggle_float_win).hide, 'expected toggle show to unhide the window')
  assert_equal(vim.api.nvim_win_get_buf(toggle_float_win), toggle_buf, 'expected toggle show to reuse the existing buffer')
  assert_equal(recorded.termopen_cmd, nil, 'expected toggle show to NOT call termopen again')
  assert_equal(recorded.open_win, nil, 'expected toggle show to NOT create a new window')

  -- Clean up via TermClose
  vim.api.nvim_exec_autocmds('TermClose', { buffer = toggle_buf })
  vim.wait(100, function()
    return not vim.api.nvim_buf_is_valid(toggle_buf) and not vim.api.nvim_win_is_valid(toggle_float_win)
  end)

  assert_truthy(not vim.api.nvim_buf_is_valid(toggle_buf), 'expected toggle TermClose to wipe the buffer')
  assert_truthy(not vim.api.nvim_win_is_valid(toggle_float_win), 'expected toggle TermClose to close the float')

  -- == Test 4: BufLeave hides float (doesn't kill job) ==

  reset_records()
  termopen_result = 77

  local leave_starting_win = vim.api.nvim_get_current_win()
  local leave_starting_tab = vim.api.nvim_get_current_tabpage()
  vim.cmd 'vsplit'
  local leave_destination_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(leave_starting_win)
  local leave_starting_float_count = count_float_windows()
  local leave_float_win, leave_buf = launch_lazygit('BufLeave hide')

  assert_equal(vim.api.nvim_get_current_tabpage(), leave_starting_tab, 'expected lazygit to stay in the origin tab while floating')

  -- Switch to another window triggers BufLeave
  reset_records()
  vim.api.nvim_set_current_win(leave_destination_win)

  assert_win_hidden(leave_float_win, 'expected BufLeave to hide the float window')
  assert_truthy(vim.api.nvim_buf_is_valid(leave_buf), 'expected BufLeave to keep the buffer alive')
  assert_equal(recorded.jobstop, nil, 'expected BufLeave to NOT stop the job')
  assert_equal(count_float_windows(), leave_starting_float_count, 'expected BufLeave to have no visible float windows')
  assert_equal(vim.api.nvim_get_current_win(), leave_destination_win, 'expected BufLeave to keep focus on the destination window')
  assert_equal(vim.api.nvim_get_current_tabpage(), leave_starting_tab, 'expected BufLeave to keep focus in the origin tab')

  -- Clean up via TermClose
  vim.api.nvim_exec_autocmds('TermClose', { buffer = leave_buf })
  vim.wait(100, function()
    return not vim.api.nvim_buf_is_valid(leave_buf)
  end)

  assert_truthy(not vim.api.nvim_buf_is_valid(leave_buf), 'expected TermClose after BufLeave to wipe the buffer')

  -- == Test 5: Termopen error ==

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

  -- == Test 6: Open_win failure ==

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

  -- == Test 7: Async TermClose ==

  local lazygit_async_starting_win = vim.api.nvim_get_current_win()
  local lazygit_async_starting_tab = vim.api.nvim_get_current_tabpage()
  termopen_mode = 'real_async'

  local lazygit_async_win, lazygit_async_buf = launch_lazygit('async TermClose')

  assert_equal(vim.api.nvim_get_current_tabpage(), lazygit_async_starting_tab, 'expected lazygit async launch to stay in the current tab while floating')

  vim.wait(1000, function()
    return not vim.api.nvim_win_is_valid(lazygit_async_win)
      and not vim.api.nvim_buf_is_valid(lazygit_async_buf)
  end)

  assert_truthy(not vim.api.nvim_win_is_valid(lazygit_async_win), 'expected lazygit async exit to close the float window')
  assert_truthy(not vim.api.nvim_buf_is_valid(lazygit_async_buf), 'expected lazygit async exit to wipe the terminal buffer')
  assert_equal(vim.api.nvim_get_current_win(), lazygit_async_starting_win, 'expected lazygit async exit to restore focus to the origin window')

  termopen_mode = 'pass'

  -- == Test 8: Lazygit dies while hidden (stale process detection) ==

  reset_records()
  termopen_result = 77
  jobwait_result = { -1 }

  local dead_starting_win = vim.api.nvim_get_current_win()
  local dead_float_win, dead_buf = launch_lazygit('dead while hidden')

  -- Toggle hide
  reset_records()
  callbacks['<leader>g']()

  assert_win_hidden(dead_float_win, 'expected toggle hide to hide the float')
  assert_truthy(vim.api.nvim_buf_is_valid(dead_buf), 'expected hidden lazygit to keep buffer alive')

  -- Simulate process death
  jobwait_result = { 0 }

  -- Toggle show: should detect dead process, clean up, and do fresh start
  reset_records()
  termopen_result = 88
  callbacks['<leader>g']()

  assert_truthy(recorded.termopen_cmd ~= nil, 'expected dead process detection to trigger fresh termopen')
  assert_equal(recorded.termopen_cmd[1], 'lazygit', 'expected fresh start to launch lazygit')

  local fresh_float_win = vim.api.nvim_get_current_win()
  local fresh_config = vim.api.nvim_win_get_config(fresh_float_win)
  local fresh_buf = vim.api.nvim_win_get_buf(fresh_float_win)

  assert_truthy(fresh_config.relative ~= '', 'expected fresh start to open a floating window')
  assert_truthy(fresh_buf ~= dead_buf or not vim.api.nvim_buf_is_valid(dead_buf), 'expected fresh start to use a new buffer')

  -- Clean up
  jobwait_result = { -1 }
  vim.api.nvim_exec_autocmds('TermClose', { buffer = fresh_buf })
  vim.wait(100, function()
    return not vim.api.nvim_buf_is_valid(fresh_buf) and not vim.api.nvim_win_is_valid(fresh_float_win)
  end)

  assert_truthy(not vim.api.nvim_buf_is_valid(fresh_buf), 'expected fresh start TermClose to wipe the buffer')

  -- == Test 9: Re-show from different window (origin_win update) ==

  reset_records()
  termopen_result = 77
  jobwait_result = { -1 }

  local reshow_win_a = vim.api.nvim_get_current_win()
  vim.cmd 'vsplit'
  local reshow_win_b = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(reshow_win_a)

  -- Launch from window A
  local reshow_float_win, reshow_buf = launch_lazygit('reshow origin')

  -- Toggle hide (back to window A)
  reset_records()
  callbacks['<leader>g']()

  -- Move to window B
  vim.api.nvim_set_current_win(reshow_win_b)

  -- Re-show from window B (should reuse same hidden window)
  reset_records()
  callbacks['<leader>g']()

  assert_equal(vim.api.nvim_get_current_win(), reshow_float_win, 'expected re-show from B to reuse the same float window')
  assert_truthy(not vim.api.nvim_win_get_config(reshow_float_win).hide, 'expected re-show from B to unhide the float')
  assert_equal(vim.api.nvim_win_get_buf(reshow_float_win), reshow_buf, 'expected re-show from B to reuse the buffer')
  assert_equal(recorded.open_win, nil, 'expected re-show from B to NOT create a new window')

  -- TermClose should NOT jump to window A (origin_win updated to B)
  vim.api.nvim_exec_autocmds('TermClose', { buffer = reshow_buf })
  vim.wait(100, function()
    return not vim.api.nvim_buf_is_valid(reshow_buf) and not vim.api.nvim_win_is_valid(reshow_float_win)
  end)

  assert_truthy(not vim.api.nvim_buf_is_valid(reshow_buf), 'expected reshow TermClose to wipe the buffer')
  assert_equal(vim.api.nvim_get_current_win(), reshow_win_b, 'expected reshow TermClose to restore focus to window B, not A')

  -- == Test 10: lazygit remote edit opens in the origin window ==

  reset_records()
  termopen_result = 77

  local lazygit_edit_origin_win = vim.api.nvim_get_current_win()
  local lazygit_edit_file = vim.fn.tempname() .. '.txt'
  vim.fn.writefile({ 'alpha', 'beta', 'gamma' }, lazygit_edit_file)

  local lazygit_edit_float_win, lazygit_edit_buf = launch_lazygit('remote edit')

  assert_truthy(type(_G._lazygit_remote_edit) == 'function', 'expected _lazygit_remote_edit helper')

  _G._lazygit_remote_edit(lazygit_edit_file, 3)

  assert_equal(vim.api.nvim_get_current_win(), lazygit_edit_origin_win, 'expected lazygit remote edit to restore the origin window')
  assert_equal(vim.api.nvim_buf_get_name(0), vim.fs.normalize(lazygit_edit_file), 'expected lazygit remote edit to open the requested file')
  assert_equal(vim.api.nvim_win_get_cursor(0)[1], 3, 'expected lazygit remote edit to jump to the requested line')
  assert_win_hidden(lazygit_edit_float_win, 'expected lazygit remote edit to hide the float window')
  assert_truthy(vim.api.nvim_buf_is_valid(lazygit_edit_buf), 'expected lazygit remote edit to keep the terminal buffer alive')
  assert_equal(recorded.jobstop, nil, 'expected lazygit remote edit to avoid stopping the terminal job')

  vim.api.nvim_exec_autocmds('TermClose', { buffer = lazygit_edit_buf })
  vim.wait(100, function()
    return not vim.api.nvim_buf_is_valid(lazygit_edit_buf) and not vim.api.nvim_win_is_valid(lazygit_edit_float_win)
  end)

  assert_truthy(vim.fn.delete(lazygit_edit_file) == 0, 'expected lazygit remote edit temp file cleanup to succeed')

  -- == GitUI tests (float + nvim remote) ==

  reset_records()
  termopen_result = 77

  -- Test 10: gitui float launch + nvim remote cmd
  local gitui_starting_win = vim.api.nvim_get_current_win()
  local gitui_starting_tab = vim.api.nvim_get_current_tabpage()

  local gitui_float_win, gitui_buf = launch_gitui('gitui float launch')

  assert_equal(vim.api.nvim_get_current_tabpage(), gitui_starting_tab, 'expected gitui to stay in the current tab (float, not new tab)')

  -- Verify nvim remote: cmd should be { 'env', 'EDITOR=...', 'gitui' }
  assert_equal(recorded.termopen_cmd[1], 'env', 'expected gitui cmd to start with env')
  assert_equal(recorded.termopen_cmd[3], 'gitui', 'expected gitui cmd to end with gitui')
  local gitui_editor_arg = recorded.termopen_cmd[2]
  assert_truthy(gitui_editor_arg:match('^EDITOR='), 'expected gitui cmd to set EDITOR env var')
  local gitui_script_path = gitui_editor_arg:match('^EDITOR=(.+)$')
  assert_truthy(vim.fn.filereadable(gitui_script_path) == 1, 'expected nvim remote temp script to exist')

  -- Verify script content
  local gitui_script_lines = vim.fn.readfile(gitui_script_path)
  assert_truthy(gitui_script_lines[1]:match('#!/usr/bin/env bash'), 'expected temp script to have bash shebang')
  assert_truthy(gitui_script_lines[2]:match('nvim %-%-server .+ %-%-remote%-send'), 'expected temp script to contain nvim --server --remote-send command')
  assert_truthy(gitui_script_lines[2]:match('_gitui_remote_edit'), 'expected temp script to call _gitui_remote_edit')

  -- Test 11: gitui toggle hide/show
  reset_records()
  callbacks['<leader>G']()

  assert_win_hidden(gitui_float_win, 'expected gitui toggle hide to hide the float window')
  assert_truthy(vim.api.nvim_buf_is_valid(gitui_buf), 'expected gitui toggle hide to keep the buffer alive')
  assert_equal(recorded.jobstop, nil, 'expected gitui toggle hide to NOT stop the job')

  reset_records()
  callbacks['<leader>G']()

  assert_equal(vim.api.nvim_get_current_win(), gitui_float_win, 'expected gitui toggle show to reuse the same window')
  assert_truthy(not vim.api.nvim_win_get_config(gitui_float_win).hide, 'expected gitui toggle show to unhide the window')
  assert_equal(vim.api.nvim_win_get_buf(gitui_float_win), gitui_buf, 'expected gitui toggle show to reuse the existing buffer')
  assert_equal(recorded.termopen_cmd, nil, 'expected gitui toggle show to NOT call termopen again')

  -- Test 12: gitui TermClose cleanup + temp script deletion
  vim.api.nvim_exec_autocmds('TermClose', { buffer = gitui_buf })
  vim.wait(100, function()
    return not vim.api.nvim_buf_is_valid(gitui_buf) and not vim.api.nvim_win_is_valid(gitui_float_win)
  end)

  assert_truthy(not vim.api.nvim_buf_is_valid(gitui_buf), 'expected gitui TermClose to wipe the terminal buffer')
  assert_truthy(not vim.api.nvim_win_is_valid(gitui_float_win), 'expected gitui TermClose to close the float window')
  assert_truthy(vim.fn.filereadable(gitui_script_path) == 0, 'expected gitui TermClose to delete the nvim remote temp script')

  -- Test 13: gitui termopen error + temp script cleanup on error
  reset_records()
  termopen_result = 77
  termopen_mode = 'error'

  -- Capture temp script path via tempname mock
  local original_tempname = vim.fn.tempname
  local captured_tempname = nil
  vim.fn.tempname = function()
    captured_tempname = original_tempname()
    return captured_tempname
  end

  local gitui_error_starting_win = vim.api.nvim_get_current_win()
  local gitui_error_starting_float_count = count_float_windows()

  local gitui_error_ok, gitui_error_err = pcall(callbacks['<leader>G'])

  vim.fn.tempname = original_tempname

  assert_truthy(gitui_error_ok, 'expected gitui termopen error to be handled without error')
  assert_equal(vim.api.nvim_get_current_win(), gitui_error_starting_win, 'expected gitui termopen error to restore focus')
  assert_equal(count_float_windows(), gitui_error_starting_float_count, 'expected gitui termopen error to close the float window')
  assert_truthy(#recorded.notify > 0, 'expected gitui termopen error to notify the user')

  -- Verify temp script was cleaned up on error (toggle_git_float calls opts.on_cleanup)
  if captured_tempname then
    local gitui_error_script = captured_tempname .. '.sh'
    assert_truthy(vim.fn.filereadable(gitui_error_script) == 0, 'expected temp script to be cleaned up after termopen error')
  end

  termopen_mode = 'pass'

  -- Note: servername fallback test (vim.v.servername == '') is omitted because
  -- vim.v.servername is read-only in Neovim. The fallback is a 2-line if-check
  -- in make_gitui_cmd and can be verified by manual testing.
end)

restore()

if not test_ok then
  error(test_err)
end
