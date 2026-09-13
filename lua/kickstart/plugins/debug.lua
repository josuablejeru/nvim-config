-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Current debugger targets:
--   * JavaScript / TypeScript: `js-debug-adapter`, configured below as `pwa-node`
--   * C / C++: `codelldb`, configured by mason-nvim-dap defaults
--   * Python: `debugpy`, configured below with uv/.venv detection
--   * JVM:
--       - Kotlin: `kotlin-debug-adapter`, configured by mason-nvim-dap defaults
--       - Java: `java-debug-adapter` + `java-test` are installed here, but Java
--         debugging still needs jdtls/nvim-jdtls project integration to register
--         the runtime adapter and per-project launch configs.
--
-- To onboard another language later:
--   1. Find its Mason DAP adapter name in `:Mason` or mason-nvim-dap's mappings.
--   2. Add that adapter name to `ensure_installed` below.
--   3. If mason-nvim-dap has defaults for it, no more config is usually needed.
--   4. If not, define `dap.adapters.<name>` and `dap.configurations.<filetype>`.

vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
  'https://github.com/leoluz/nvim-dap-go',
}

local dap = require 'dap'
local dapui = require 'dapui'

local function debug_map(keys, rhs, desc) vim.keymap.set('n', '<leader>d' .. keys, rhs, { desc = '[D]ebug: ' .. desc }) end

debug_map('c', dap.continue, '[C]ontinue / start')
debug_map('p', dap.pause, '[P]ause')
debug_map('t', dap.terminate, '[T]erminate')
debug_map('r', dap.run_last, '[R]un last')
debug_map('i', dap.step_into, 'Step [I]nto')
debug_map('o', dap.step_over, 'Step [O]ver')
debug_map('O', dap.step_out, 'Step [O]ut')
debug_map('b', dap.toggle_breakpoint, 'Toggle [B]reakpoint')
debug_map('B', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, 'Set conditional [B]reakpoint')
debug_map('l', function() dap.set_breakpoint(nil, nil, vim.fn.input 'Log point message: ') end, 'Set [L]og point')
debug_map('u', dapui.toggle, 'Toggle [U]I')
debug_map('h', function() require('dap.ui.widgets').hover() end, '[H]over value')
debug_map('R', function() dap.repl.open() end, 'Open [R]EPL')

require('mason-nvim-dap').setup {
  -- Makes a best effort to setup the various debuggers with
  -- reasonable debug configurations
  automatic_installation = true,

  -- You can provide additional configuration to the handlers,
  -- see mason-nvim-dap README for more information
  handlers = {},

  -- You'll need to check that you have the required things installed
  -- online, please don't ask me how to install them :)
  ensure_installed = {
    -- Update this to ensure that you have the debuggers for the langs you want
    'codelldb',
    'delve',
    'javadbg',
    'javatest',
    'js',
    'kotlin',
    'python',
  },
}

local js_debug_adapter = {
  type = 'server',
  host = 'localhost',
  port = '${port}',
  executable = {
    command = 'js-debug-adapter',
    args = { '${port}' },
  },
}

dap.adapters['pwa-node'] = js_debug_adapter

local js_debug_configurations = {
  {
    type = 'pwa-node',
    request = 'launch',
    name = 'Node: Launch file',
    program = '${file}',
    cwd = '${workspaceFolder}',
    sourceMaps = true,
    skipFiles = { '<node_internals>/**' },
    console = 'integratedTerminal',
  },
  {
    type = 'pwa-node',
    request = 'attach',
    name = 'Node: Attach process',
    processId = require('dap.utils').pick_process,
    cwd = '${workspaceFolder}',
    sourceMaps = true,
    skipFiles = { '<node_internals>/**' },
  },
  {
    type = 'pwa-node',
    request = 'attach',
    name = 'Node: Attach localhost:9229',
    address = 'localhost',
    port = 9229,
    cwd = '${workspaceFolder}',
    sourceMaps = true,
    skipFiles = { '<node_internals>/**' },
  },
}

for _, filetype in ipairs { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' } do
  dap.configurations[filetype] = js_debug_configurations
end

local function python_from_venv(venv)
  local python = vim.fn.has 'win32' == 1 and vim.fs.joinpath(venv, 'Scripts', 'python.exe') or vim.fs.joinpath(venv, 'bin', 'python')
  if vim.fn.executable(python) == 1 then return python end
end

local function python_project_root()
  local bufname = vim.api.nvim_buf_get_name(0)
  local start = bufname ~= '' and vim.fs.dirname(bufname) or vim.uv.cwd()
  return vim.fs.root(start, { 'uv.lock', 'pyproject.toml', '.git' }) or start
end

local function python_path()
  if vim.env.VIRTUAL_ENV then
    local python = python_from_venv(vim.env.VIRTUAL_ENV)
    if python then return python end
  end

  if vim.env.CONDA_PREFIX then
    local python = python_from_venv(vim.env.CONDA_PREFIX)
    if python then return python end
  end

  local project_python = python_from_venv(vim.fs.joinpath(python_project_root(), '.venv'))
  if project_python then return project_python end

  local python3 = vim.fn.exepath 'python3'
  if python3 ~= '' then return python3 end

  return vim.fn.exepath 'python'
end

local function input_args() return vim.split(vim.fn.input 'Args: ', ' +', { trimempty = true }) end

dap.configurations.python = {
  {
    type = 'python',
    request = 'launch',
    name = 'Python: Launch file',
    program = '${file}',
    cwd = python_project_root,
    pythonPath = python_path,
    console = 'integratedTerminal',
    justMyCode = false,
  },
  {
    type = 'python',
    request = 'launch',
    name = 'Python: Launch file (args)',
    program = '${file}',
    args = input_args,
    cwd = python_project_root,
    pythonPath = python_path,
    console = 'integratedTerminal',
    justMyCode = false,
  },
  {
    type = 'python',
    request = 'launch',
    name = 'Python: Launch module',
    module = function() return vim.fn.input 'Module: ' end,
    args = input_args,
    cwd = python_project_root,
    pythonPath = python_path,
    console = 'integratedTerminal',
    justMyCode = false,
  },
  {
    type = 'python',
    request = 'launch',
    name = 'Python: Pytest current file',
    module = 'pytest',
    args = function() return { '${file}' } end,
    cwd = python_project_root,
    pythonPath = python_path,
    console = 'integratedTerminal',
    justMyCode = false,
  },
}

-- Dap UI setup
-- For more information, see |:help nvim-dap-ui|
---@diagnostic disable-next-line: missing-fields
dapui.setup {
  -- Set icons to characters that are more likely to work in every terminal.
  --    Feel free to remove or use ones that you like more! :)
  --    Don't feel like these are good choices.
  icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
  ---@diagnostic disable-next-line: missing-fields
  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

-- Change breakpoint icons
-- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
-- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
-- local breakpoint_icons = vim.g.have_nerd_font
--     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
--   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
-- for type, icon in pairs(breakpoint_icons) do
--   local tp = 'Dap' .. type
--   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
--   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
-- end

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close

-- Install golang specific config
require('dap-go').setup {
  delve = {
    -- On Windows delve must be run attached or it crashes.
    -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
    detached = vim.fn.has 'win32' == 0,
  },
}
