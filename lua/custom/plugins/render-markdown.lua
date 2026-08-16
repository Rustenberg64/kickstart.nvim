return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  cmd = { 'RenderMarkdown' },
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-mini/mini.nvim',
  },
  opts = {
    latex = { enabled = false },
  },
}
