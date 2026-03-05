return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'olimorris/neotest-rspec',
  },
  keys = {
    { '<leader>tn', function() require('neotest').run.run() end, desc = 'Run nearest test' },
    { '<leader>tf', function() require('neotest').run.run(vim.fn.expand '%') end, desc = 'Run file tests' },
    { '<leader>to', function() require('neotest').output.open { enter_test = true } end, desc = 'Test output' },
    { '<leader>ts', function() require('neotest').summary.toggle() end, desc = 'Test summary' },
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
