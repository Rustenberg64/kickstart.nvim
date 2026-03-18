return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'olimorris/neotest-rspec',
  },
  keys = {
    { '<leader>Tn', function() require('neotest').run.run() end, desc = '[T]est [N]earest' },
    { '<leader>Tf', function() require('neotest').run.run(vim.fn.expand '%') end, desc = '[T]est [F]ile' },
    { '<leader>To', function() require('neotest').output.open { enter_test = true } end, desc = '[T]est [O]utput' },
    { '<leader>Ts', function() require('neotest').summary.toggle() end, desc = '[T]est [S]ummary' },
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-rspec' {
          root_files = { '.git', 'Gemfile', '.rspec', '.gitignore' },
          rspec_cmd = function()
            local script_path = vim.fn.getcwd() .. '/.local/bin/run_rspec.sh'
            if vim.fn.filereadable(script_path) == 1 then
              return { script_path }
            else
              return { 'bundle', 'exec', 'rspec' }
            end
          end,
        },
      },
    }
  end,
}
