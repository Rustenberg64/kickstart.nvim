local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then error(string.format('%s: expected %s, got %s', message, vim.inspect(expected), vim.inspect(actual))) end
end

local function assert_truthy(value, message)
  if not value then error(message) end
end

local function wait_for(predicate, message) assert_truthy(vim.wait(3000, predicate, 25), message) end

local function plugin_loaded()
  local plugin = require('lazy.core.config').plugins['markdown-preview.nvim']
  return plugin and plugin._.loaded ~= nil
end

local function buffer_has_command(buf, command) return vim.api.nvim_buf_get_commands(buf, {})[command] ~= nil end

assert_truthy(not plugin_loaded(), 'expected markdown-preview.nvim to start unloaded')

local lua_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(lua_buf)
vim.bo[lua_buf].filetype = 'lua'
assert_truthy(not plugin_loaded(), 'expected a non-Markdown buffer not to load the preview integration')

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
  '```flowchart',
  'st=>start: Start',
  'e=>end: End',
  'st->e',
  '```',
  '',
}

local markdown_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(markdown_buf)
vim.api.nvim_buf_set_lines(markdown_buf, 0, -1, false, source)
vim.bo[markdown_buf].filetype = 'markdown'

wait_for(plugin_loaded, 'expected a Markdown buffer to load the preview integration')
for _, command in ipairs { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' } do
  assert_truthy(buffer_has_command(markdown_buf, command), string.format('expected %s in Markdown buffers', command))
  assert_truthy(not buffer_has_command(lua_buf, command), string.format('expected %s to be absent from unsupported buffers', command))
end

wait_for(function() return vim.treesitter.highlighter.active[markdown_buf] ~= nil end, 'expected Treesitter highlighting in Markdown buffers')
require('lazy').load { plugins = { 'nvim-lint' } }
assert_equal(require('lint').linters_by_ft.markdown, { 'markdownlint' }, 'expected the existing Markdown lint configuration')

assert_equal(vim.api.nvim_buf_get_lines(markdown_buf, 0, -1, false), source, 'expected preview availability to preserve raw Markdown source')
local output_path = vim.fn.tempname() .. '.md'
vim.api.nvim_buf_set_name(markdown_buf, output_path)
vim.cmd 'silent noautocmd write'
assert_equal(vim.fn.readfile(output_path), source, 'expected saving to persist only Markdown source')
assert_equal(vim.fn.delete(output_path), 0, 'expected the temporary Markdown file to be removed')

vim.api.nvim_out_write 'markdown-preview behavior: ok\n'
