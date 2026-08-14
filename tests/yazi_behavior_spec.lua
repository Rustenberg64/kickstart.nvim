local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(string.format('%s: expected %s, got %s', message, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_truthy(value, message)
  if not value then error(message) end
end

require('lazy').load { plugins = { 'yazi.nvim' } }

local yazi = require 'yazi'
local plenary_path = require 'plenary.path'
local event_handling = require 'yazi.event_handling.yazi_event_handling'

assert_equal(yazi.config.open_for_directories, false, 'expected directory hijacking to stay disabled')
assert_equal(yazi.config.open_multiple_tabs, false, 'expected multiple-tab startup to stay disabled')
assert_equal(yazi.config.change_neovim_cwd_on_close, false, 'expected cwd changes to stay disabled')

local fixture_dir = vim.fn.tempname()
assert_equal(vim.fn.mkdir(fixture_dir, 'p'), 1, 'expected fixture directory creation to succeed')
fixture_dir = vim.uv.fs_realpath(fixture_dir) or vim.fs.normalize(fixture_dir)

local current_file = vim.fs.joinpath(fixture_dir, 'current.txt')
local selected_file = vim.fs.joinpath(fixture_dir, 'selected.txt')
local rename_from = vim.fs.joinpath(fixture_dir, 'rename-from.txt')
local rename_to = vim.fs.joinpath(fixture_dir, 'rename-to.txt')
local move_dir = vim.fs.joinpath(fixture_dir, 'moved')
local move_to = vim.fs.joinpath(move_dir, 'rename-to.txt')
local keeper_file = vim.fs.joinpath(fixture_dir, 'keeper.txt')

for _, path in ipairs { current_file, selected_file, rename_from, keeper_file } do
  assert_equal(vim.fn.writefile({ path }, path), 0, 'expected fixture file creation to succeed')
end
assert_equal(vim.fn.mkdir(move_dir, 'p'), 1, 'expected move directory creation to succeed')

local original_process = package.loaded['yazi.process.yazi_process']
local original_get_clients = vim.lsp.get_clients

local fake_process = {
  captured_paths = {},
  selected_files = {},
}

function fake_process:start(_, paths, callbacks)
  self.captured_paths = vim.tbl_map(function(path) return path.filename end, paths)
  local context = { api = {} }
  callbacks.on_exit(0, self.selected_files, nil, plenary_path:new(fixture_dir))
  return { yazi_job_id = 1 }, context
end

local function reset_to_one_window()
  vim.cmd 'silent! only!'
  vim.cmd 'silent! enew!'
end

local test_ok, test_error = pcall(function()
  package.loaded['yazi.process.yazi_process'] = fake_process

  -- Current-file reveal and cancellation preserve the origin state.
  reset_to_one_window()
  vim.cmd('edit ' .. vim.fn.fnameescape(current_file))
  local origin_win = vim.api.nvim_get_current_win()
  local origin_buf = vim.api.nvim_get_current_buf()
  local origin_cwd = vim.fn.getcwd()
  fake_process.selected_files = {}
  yazi.yazi { keymaps = false }

  assert_equal(fake_process.captured_paths[1], current_file, 'expected Yazi to receive the current file first')
  assert_equal(vim.api.nvim_get_current_win(), origin_win, 'expected cancellation to restore the origin window')
  assert_equal(vim.api.nvim_get_current_buf(), origin_buf, 'expected cancellation to preserve the origin buffer')
  assert_equal(vim.fn.getcwd(), origin_cwd, 'expected cancellation to preserve the cwd')

  -- An unnamed buffer falls back to Neovim's cwd.
  vim.cmd 'enew!'
  assert_equal(vim.api.nvim_buf_get_name(0), '', 'expected an unnamed buffer fixture')
  fake_process.selected_files = {}
  yazi.yazi { keymaps = false }
  assert_equal(
    vim.fs.normalize(fake_process.captured_paths[1]),
    vim.fs.normalize(vim.fn.getcwd()),
    'expected an unnamed buffer to open Yazi at the cwd'
  )

  -- A chooser result opens in the originating window without changing cwd.
  vim.cmd('edit ' .. vim.fn.fnameescape(current_file))
  origin_win = vim.api.nvim_get_current_win()
  origin_cwd = vim.fn.getcwd()
  fake_process.selected_files = { selected_file }
  yazi.yazi { keymaps = false }
  assert_equal(vim.api.nvim_get_current_win(), origin_win, 'expected selection to restore the origin window')
  assert_equal(vim.api.nvim_buf_get_name(0), selected_file, 'expected the chosen file in the origin window')
  assert_equal(vim.fn.getcwd(), origin_cwd, 'expected selection to preserve the cwd')

  -- Use the real event handlers with a supporting LSP client.
  package.loaded['yazi.process.yazi_process'] = original_process
  local lsp_calls = {}
  local client = {
    offset_encoding = 'utf-16',
    server_capabilities = {},
    supports_method = function(method)
      return method == 'workspace/willRenameFiles' or method == 'workspace/didRenameFiles'
    end,
    request_sync = function(method, params)
      table.insert(lsp_calls, { kind = 'request', method = method, params = params })
      return { result = nil }
    end,
    notify = function(method, params)
      table.insert(lsp_calls, { kind = 'notify', method = method, params = params })
    end,
  }
  vim.lsp.get_clients = function() return { client } end

  reset_to_one_window()
  vim.cmd('edit ' .. vim.fn.fnameescape(rename_from))
  local renamed_buf = vim.api.nvim_get_current_buf()
  vim.cmd('vsplit ' .. vim.fn.fnameescape(keeper_file))
  local window_count = #vim.api.nvim_list_wins()

  assert_truthy(vim.uv.fs_rename(rename_from, rename_to), 'expected fixture rename to succeed')
  event_handling.process_event_emitted_from_yazi({
    type = 'rename',
    yazi_id = 'smoke-test',
    data = { from = rename_from, to = rename_to },
  }, yazi.config, {})
  vim.wait(1000, function() return vim.api.nvim_buf_get_name(renamed_buf) == rename_to end)
  assert_equal(vim.api.nvim_buf_get_name(renamed_buf), rename_to, 'expected rename to update the open buffer')

  assert_truthy(vim.uv.fs_rename(rename_to, move_to), 'expected fixture move to succeed')
  event_handling.process_event_emitted_from_yazi({
    type = 'move',
    yazi_id = 'smoke-test',
    data = { items = { { from = rename_to, to = move_to } } },
  }, yazi.config, {})
  vim.wait(1000, function() return vim.api.nvim_buf_get_name(renamed_buf) == move_to end)
  assert_equal(vim.api.nvim_buf_get_name(renamed_buf), move_to, 'expected move to update the open buffer')

  assert_equal(vim.fn.delete(move_to), 0, 'expected fixture deletion to succeed')
  event_handling.process_event_emitted_from_yazi({
    type = 'delete',
    yazi_id = 'smoke-test',
    data = { urls = { move_to } },
  }, yazi.config, {})
  vim.wait(1000, function() return not vim.api.nvim_buf_is_valid(renamed_buf) end)
  assert_truthy(not vim.api.nvim_buf_is_valid(renamed_buf), 'expected deletion to close the matching buffer')
  assert_equal(#vim.api.nvim_list_wins(), window_count, 'expected deletion to preserve the window layout')

  local methods = {}
  for _, call in ipairs(lsp_calls) do methods[call.method] = true end
  assert_truthy(methods['workspace/willRenameFiles'], 'expected willRenameFiles LSP request')
  assert_truthy(methods['workspace/didRenameFiles'], 'expected didRenameFiles LSP notification')

  -- Existing Neo-tree and Telescope mappings remain registered.
  local has_neotree = false
  local has_telescope = false
  for _, mapping in ipairs(vim.api.nvim_get_keymap 'n') do
    has_neotree = has_neotree or mapping.desc == 'NeoTree reveal'
    has_telescope = has_telescope or mapping.desc == '[S]earch [F]iles'
  end
  assert_truthy(has_neotree, 'expected the existing Neo-tree mapping')
  assert_truthy(has_telescope, 'expected the existing Telescope file-search mapping')
end)

package.loaded['yazi.process.yazi_process'] = original_process
vim.lsp.get_clients = original_get_clients
reset_to_one_window()
vim.fn.delete(fixture_dir, 'rf')

if not test_ok then error(test_error) end
