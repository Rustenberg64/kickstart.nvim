local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then error(string.format('%s: expected %s, got %s', message, vim.inspect(expected), vim.inspect(actual))) end
end

local function assert_truthy(value, message)
  if not value then error(message) end
end

local function wait_for(predicate, message) assert_truthy(vim.wait(3000, predicate, 25), message) end

local function wait_for_render_debounce()
  vim.wait(150, function() return false end, 25)
end

assert_truthy(package.loaded['render-markdown'] == nil, 'expected render-markdown.nvim to start unloaded')

local lua_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(lua_buf)
vim.bo[lua_buf].filetype = 'lua'
assert_truthy(package.loaded['render-markdown'] == nil, 'expected a non-Markdown buffer not to load the renderer')

local source = {
  '# Heading',
  '',
  '- List item',
  '- [ ] Task item',
  '',
  '> Block quote',
  '',
  '| Column | Value |',
  '| --- | --- |',
  '| A | B |',
  '',
  '[Link](https://example.com)',
  '',
  '```lua',
  "print('hello')",
  '```',
  '',
}

local markdown_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(markdown_buf)
vim.api.nvim_buf_set_lines(markdown_buf, 0, -1, false, source)
vim.bo[markdown_buf].filetype = 'markdown'

wait_for(function() return package.loaded['render-markdown'] ~= nil end, 'expected a Markdown buffer to load the renderer')

local manager = require 'render-markdown.core.manager'
wait_for(function() return manager.attached(markdown_buf) end, 'expected the renderer to attach to the Markdown buffer')
assert_truthy(not manager.attached(lua_buf), 'expected the renderer not to attach to the Lua buffer')
assert_equal(vim.fn.exists ':RenderMarkdown', 2, 'expected the RenderMarkdown command')

local state = require 'render-markdown.state'
local config = state.get(markdown_buf)
assert_truthy(config.enabled, 'expected rendering to start enabled')
assert_truthy(config.resolved:render 'n', 'expected normal mode to render Markdown')
assert_truthy(not config.resolved:render 'i', 'expected insert mode to show raw Markdown')
assert_truthy(not config.latex.enabled, 'expected LaTeX rendering to remain disabled')

vim.api.nvim_win_set_cursor(0, { #source, 0 })
require('render-markdown').render { buf = markdown_buf }

local namespace = vim.api.nvim_get_namespaces()['render-markdown.nvim']
assert_truthy(namespace ~= nil, 'expected the render-markdown namespace')

local function extmarks() return vim.api.nvim_buf_get_extmarks(markdown_buf, namespace, 0, -1, { details = true }) end

wait_for(function() return #extmarks() > 0 end, 'expected rendered Markdown extmarks')

local rendered = vim.inspect(extmarks())
for _, highlight in ipairs {
  'RenderMarkdownH1',
  'RenderMarkdownBullet',
  'RenderMarkdownUnchecked',
  'RenderMarkdownQuote',
  'RenderMarkdownTable',
  'RenderMarkdownLink',
  'RenderMarkdownCode',
} do
  assert_truthy(rendered:find(highlight, 1, true), string.format('expected rendered structure using %s', highlight))
end

wait_for_render_debounce()
vim.cmd 'RenderMarkdown toggle'
wait_for(function() return not require('render-markdown').get() end, 'expected toggle to disable rendering')
wait_for(function() return not state.get(markdown_buf).enabled end, 'expected toggle to disable the Markdown buffer')
if not vim.wait(3000, function() return #extmarks() == 0 end, 25) then
  error(string.format('expected raw view to clear renderer extmarks: %d remain', #extmarks()))
end

wait_for_render_debounce()
vim.cmd 'RenderMarkdown toggle'
wait_for(function() return require('render-markdown').get() end, 'expected toggle to re-enable rendering')
wait_for(function() return #extmarks() > 0 end, 'expected rendered view to restore renderer extmarks')
assert_equal(vim.api.nvim_buf_get_lines(markdown_buf, 0, -1, false), source, 'expected rendering to preserve buffer source')

local output_path = vim.fn.tempname() .. '.md'
vim.api.nvim_buf_set_name(markdown_buf, output_path)
vim.cmd 'silent noautocmd write'
assert_equal(vim.fn.readfile(output_path), source, 'expected saving not to persist presentation-only content')
assert_equal(vim.fn.delete(output_path), 0, 'expected the temporary Markdown file to be removed')

vim.api.nvim_out_write 'render-markdown behavior: ok\n'
