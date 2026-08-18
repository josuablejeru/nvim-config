-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
  'https://github.com/nvim-tree/nvim-web-devicons',
}

vim.keymap.set('n', '<leader>e', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

require('neo-tree').setup {
  close_if_last_window = false,
  enable_git_status = true,
  filesystem = {
    filtered_items = {
      hide_dotfiles = false,
      hide_gitignored = false,
    },
    window = {
      mappings = {
        ['q'] = 'close_window',
      },
    },
  },
}
