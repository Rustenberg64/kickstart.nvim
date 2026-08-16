local this_file = debug.getinfo(1, 'S').source:sub(2)
local tests_dir = vim.fs.dirname(this_file)
local plugin_path = vim.fs.normalize(vim.fs.joinpath(tests_dir, '..', 'lua', 'custom', 'plugins', 'render-markdown.lua'))

local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then error(string.format('%s: expected %s, got %s', message, vim.inspect(expected), vim.inspect(actual))) end
end

local function assert_truthy(value, message)
  if not value then error(message) end
end

local plugin = dofile(plugin_path)

assert_equal(plugin[1], 'MeanderingProgrammer/render-markdown.nvim', 'expected render-markdown.nvim plugin')
assert_equal(plugin.ft, { 'markdown' }, 'expected Markdown-only filetype loading')
assert_equal(plugin.cmd, { 'RenderMarkdown' }, 'expected the RenderMarkdown command trigger')

local dependencies = {}
for _, dependency in ipairs(plugin.dependencies or {}) do
  local name = type(dependency) == 'table' and dependency[1] or dependency
  dependencies[name] = true
end

assert_truthy(dependencies['nvim-treesitter/nvim-treesitter'], 'expected the Treesitter dependency')
assert_truthy(dependencies['nvim-mini/mini.nvim'], 'expected the mini.nvim icon-provider dependency')
assert_truthy(plugin.opts.enabled == nil, 'expected the upstream enabled-by-default behavior')
assert_truthy(plugin.opts.render_modes == nil, 'expected the upstream modal rendering defaults')
assert_equal(plugin.opts.latex, { enabled = false }, 'expected unsupported LaTeX rendering to be disabled')
