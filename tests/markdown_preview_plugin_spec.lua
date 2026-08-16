local this_file = debug.getinfo(1, 'S').source:sub(2)
local tests_dir = vim.fs.dirname(this_file)
local plugin_path = vim.fs.normalize(vim.fs.joinpath(tests_dir, '..', 'lua', 'custom', 'plugins', 'markdown-preview.lua'))
local old_plugin_path = vim.fs.normalize(vim.fs.joinpath(tests_dir, '..', 'lua', 'custom', 'plugins', 'render-markdown.lua'))

local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then error(string.format('%s: expected %s, got %s', message, vim.inspect(expected), vim.inspect(actual))) end
end

local function assert_truthy(value, message)
  if not value then error(message) end
end

local plugin = dofile(plugin_path)

assert_equal(plugin[1], 'iamcco/markdown-preview.nvim', 'expected markdown-preview.nvim plugin')
assert_equal(plugin.ft, { 'markdown' }, 'expected Markdown-only filetype loading')
assert_equal(plugin.cmd, { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' }, 'expected all Markdown preview command triggers')

local original_fn = vim.fn
local installer_called = false
vim.fn = setmetatable({
  ['mkdp#util#install'] = function() installer_called = true end,
}, { __index = original_fn })
local build_ok, build_error = pcall(plugin.build)
vim.fn = original_fn
assert_truthy(build_ok, string.format('expected the prebuilt installer to run: %s', build_error))
assert_truthy(installer_called, 'expected the upstream prebuilt installation helper')

plugin.init()
assert_equal(vim.g.mkdp_filetypes, { 'markdown' }, 'expected Markdown-only preview scope')
assert_equal(vim.g.mkdp_auto_start, 0, 'expected preview startup to be manual')
assert_equal(vim.g.mkdp_auto_close, 1, 'expected preview to close automatically')
assert_equal(vim.g.mkdp_refresh_slow, 0, 'expected live preview refresh')
assert_equal(vim.g.mkdp_command_for_global, 0, 'expected preview commands to stay filetype-local')
assert_equal(vim.g.mkdp_open_to_the_world, 0, 'expected the preview server to stay localhost-only')
assert_equal(vim.fn.filereadable(old_plugin_path), 0, 'expected the old render-markdown plugin module to be removed')

for _, dependency in ipairs(plugin.dependencies or {}) do
  local name = type(dependency) == 'table' and dependency[1] or dependency
  assert_truthy(name ~= 'MeanderingProgrammer/render-markdown.nvim', 'expected the old renderer dependency to be absent')
end
