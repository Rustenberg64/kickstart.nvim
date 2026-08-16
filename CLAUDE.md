# Neovim Config

Personal Neovim setup forked from kickstart.nvim and customized.

## Architecture

```
init.lua                        # Main config: options, keymaps, plugin definitions via lazy.nvim
lua/
├── custom/plugins/             # Custom additions (auto-loaded via { import = 'custom.plugins' })
│   ├── init.lua                # Options, keymaps, autocmds, lazygit integration
│   ├── flutter-tools.lua       # Flutter development (<leader>F prefix)
│   ├── neotest.lua             # Test runner for rspec (<leader>T prefix)
│   ├── octo.lua                # GitHub issues/PRs via octo.nvim (<leader>o prefix)
│   ├── markdown-preview.lua    # Live Markdown preview in the browser
│   └── vim-tmux-navigator.lua  # Tmux pane navigation (C-hjkl)
└── kickstart/plugins/          # Bundled optional plugins (toggled via require in init.lua)
```

## Key Files

- `init.lua` — Entry point. Plugin specs, LSP, Telescope, completion all defined here
- `lua/custom/plugins/init.lua` — Custom options, keymaps, and autocmds
- `lazy-lock.json` — Plugin version lockfile (git tracked)
- `.stylua.toml` — Lua formatter config

## How to Edit

- **Add a plugin**: Create a new `.lua` file in `lua/custom/plugins/` returning a lazy.nvim spec
- **Enable a kickstart plugin**: Uncomment `require 'kickstart.plugins.xxx'` near the end of `init.lua`
- **Add keymaps/options/autocmds**: Append to `lua/custom/plugins/init.lua`
- **Add an LSP server**: Add to `local servers = { ... }` table in `init.lua`
- **Add a Treesitter parser**: Add to `local parsers = { ... }` table in `init.lua`

## Markdown Preview

Markdown stays as raw, editable source in Neovim. From a Markdown buffer, use
`:MarkdownPreview` to open the live browser preview, `:MarkdownPreviewStop` to
stop it, or `:MarkdownPreviewToggle` to switch it between running and stopped.

## Code Style

- Formatter: stylua (2-space indent, single quotes, `call_parentheses = "None"`, `collapse_simple_statement = "Always"`)
- Format on save enabled via conform.nvim
- Prefer lazy.nvim `keys` spec for keymaps to leverage lazy loading
- LazyGit uses raw `vim.fn.termopen` instead of a dedicated plugin

## Gotchas

- `lua/custom/plugins/init.lua` must `return {}` at the end (lazy.nvim import requirement)
- Default `<C-h/j/k/l>` window navigation is commented out — vim-tmux-navigator replaces it
- `<leader>T` (uppercase) is neotest, `<leader>t` (lowercase) is toggle group — watch for conflicts
- Post-update crashes: `rm -rf ~/.local/share/nvim ~/.cache/nvim`
- asdf shims PATH is prepended in `lua/custom/plugins/init.lua`
