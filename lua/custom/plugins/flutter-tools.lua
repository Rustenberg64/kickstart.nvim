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
    { '<leader>Fr', function() vim.cmd 'FlutterRun --flavor stg --dart-define=FLAVOR=stg' end, desc = 'Flutter Run (stg)' },
    { '<leader>Fq', '<cmd>FlutterQuit<cr>', desc = 'Flutter Quit' },
    { '<leader>FR', '<cmd>FlutterRestart<cr>', desc = 'Flutter Restart' },
    { '<leader>Fd', '<cmd>FlutterDevices<cr>', desc = 'Flutter Devices' },
    { '<leader>Fl', '<cmd>FlutterReload<cr>', desc = 'Flutter Reload' },
    { '<leader>Fo', '<cmd>FlutterOutlineToggle<cr>', desc = 'Flutter Outline' },
    { '<leader>Ft', '<cmd>FlutterDevTools<cr>', desc = 'Flutter DevTools' },
    { '<leader>Fs', '<cmd>FlutterLspRestart<cr>', desc = 'Flutter LSP Restart' },
    { '<leader>FL', '<cmd>FlutterLogToggle<cr>', desc = 'Flutter Log' },
    { '<leader>Fe', '<cmd>FlutterEmulators<cr>', desc = 'Flutter Emulators' },
  },
}
