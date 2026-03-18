local function asdf_flutter_path()
  if vim.fn.executable 'asdf' == 0 then return nil end

  local result = vim.fn.systemlist { 'asdf', 'which', 'flutter' }
  if vim.v.shell_error ~= 0 or not result[1] or result[1] == '' then return nil end

  return result[1]
end

return {
  'nvim-flutter/flutter-tools.nvim',
  ft = 'dart',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('flutter-tools').setup {
      -- flutter-tools mis-detects the SDK root when it starts from an asdf shim path.
      flutter_path = asdf_flutter_path(),
    }
  end,
  keys = {
    { '<leader>Fr', function() vim.cmd 'FlutterRun --flavor stg --dart-define=FLAVOR=stg' end, desc = '[F]lutter [R]un (stg)' },
    { '<leader>Fq', '<cmd>FlutterQuit<cr>', desc = '[F]lutter [Q]uit' },
    { '<leader>FR', '<cmd>FlutterRestart<cr>', desc = '[F]lutter [R]estart' },
    { '<leader>Fd', '<cmd>FlutterDevices<cr>', desc = '[F]lutter [D]evices' },
    { '<leader>Fl', '<cmd>FlutterReload<cr>', desc = '[F]lutter Re[L]oad' },
    { '<leader>Fo', '<cmd>FlutterOutlineToggle<cr>', desc = '[F]lutter [O]utline' },
    { '<leader>Ft', '<cmd>FlutterDevTools<cr>', desc = '[F]lutter Dev[T]ools' },
    { '<leader>Fs', '<cmd>FlutterLspRestart<cr>', desc = '[F]lutter L[S]P Restart' },
    { '<leader>FL', '<cmd>FlutterLogToggle<cr>', desc = '[F]lutter [L]og' },
    { '<leader>Fe', '<cmd>FlutterEmulators<cr>', desc = '[F]lutter [E]mulators' },
  },
}
