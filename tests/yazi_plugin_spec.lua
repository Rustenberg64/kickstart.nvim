local this_file = debug.getinfo(1, 'S').source:sub(2)
local tests_dir = vim.fs.dirname(this_file)
local plugin_path = vim.fs.normalize(vim.fs.joinpath(tests_dir, '..', 'lua', 'custom', 'plugins', 'yazi.lua'))

local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(string.format('%s: expected %s, got %s', message, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_truthy(value, message)
  if not value then error(message) end
end

local plugin = dofile(plugin_path)

assert_equal(plugin[1], 'mikavilpas/yazi.nvim', 'expected yazi.nvim plugin')
assert_equal(plugin.version, '*', 'expected the stable release constraint')

local has_plenary = false
for _, dependency in ipairs(plugin.dependencies or {}) do
  local name = type(dependency) == 'table' and dependency[1] or dependency
  if name == 'nvim-lua/plenary.nvim' then
    has_plenary = true
    if type(dependency) == 'table' then
      assert_equal(dependency.lazy, true, 'expected Plenary to stay lazy')
    end
  end
end
assert_truthy(has_plenary, 'expected an explicit Plenary dependency')

local yazi_key
for _, key in ipairs(plugin.keys or {}) do
  if key[1] == '<leader>-' then
    yazi_key = key
    break
  end
end

assert_truthy(yazi_key, 'expected a <leader>- mapping')
assert_equal(yazi_key[2], '<cmd>Yazi<cr>', 'expected the mapping to open Yazi at the current context')
assert_equal(yazi_key.mode, { 'n', 'v' }, 'expected the mapping in normal and visual modes')
assert_truthy(type(yazi_key.desc) == 'string' and yazi_key.desc ~= '', 'expected a mapping description')

assert_equal(plugin.opts.open_for_directories, false, 'expected directory hijacking to be disabled')
assert_equal(plugin.opts.open_multiple_tabs, false, 'expected multiple-tab startup to be disabled')
assert_equal(plugin.opts.change_neovim_cwd_on_close, false, 'expected cwd changes on close to be disabled')
