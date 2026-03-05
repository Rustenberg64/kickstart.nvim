return {
  'nvim-flutter/flutter-tools.nvim',
  ft = 'dart',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = true,
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
  },
}
