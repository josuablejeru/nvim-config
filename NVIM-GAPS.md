# Neovim config — gap analysis

Scope: everything below is derived **only** from the files in `~/.config/nvim`
(`init.lua`, `lua/kickstart/plugins/*.lua`, `lua/custom/plugins/init.lua`,
`nvim-pack-lock.json`). Nothing is implemented — this is a review.

Baseline: a kickstart.nvim config ported to `vim.pack`, reorganised into 10
numbered `do` blocks. It is clean and well-commented. The gaps below are mostly
*consistency* and *coverage*, not quality.

### 1.3 A linter is configured that the config never installs

`lua/kickstart/plugins/lint.lua` sets:

```lua
lint.linters_by_ft = { markdown = { 'markdownlint' } }
```

but `init.lua:816-819` extends Mason's `ensure_installed` with exactly one extra
tool:

```lua
vim.list_extend(ensure_installed, { 'stylua' })
```

`markdownlint` is never requested, so on every markdown `BufWritePost` /
`InsertLeave` nvim-lint tries to spawn a binary the config doesn't guarantee
exists. Either add it to `ensure_installed` or drop the linter — as written,
linting is configured but not provisioned.

### 1.4 `nvim-web-devicons` is loaded twice, two different ways

`init.lua:411-414` sets up `mini.icons` and mocks devicons:

```lua
MiniIcons.mock_nvim_web_devicons()
```

while `lua/kickstart/plugins/neo-tree.lua` pulls in the *real*
`nvim-tree/nvim-web-devicons` as a dependency. Both are in
`nvim-pack-lock.json`. Whichever wins, you're carrying a plugin you decided to
replace. (`plenary.nvim` is also added in two places — harmless and idempotent,
but same story.)

---

## Tier 2 — Language coverage: five lists that disagree with each other

Each subsystem declares its own language list, and no two match. This table is
the core finding of the review:

| Language | Treesitter (`init.lua:997`) | LSP (`init.lua:706-791`) | format-on-save (`849-855`) | formatter (`870-880`) | linter (`lint.lua`) | DAP (`debug.lua`) |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| lua        | ✅ | ✅ lua_ls | ✅ | ✅ stylua | — | — |
| python     | ✅ | ✅ pyright + ruff | ✅ | ✅ ruff_format | — | ❌ |
| rust       | ✅ | ✅ rust_analyzer | ✅ | via LSP | — | ❌ |
| c          | ✅ | ✅ clangd | ✅ | via LSP | — | ❌ |
| **cpp**    | ❌ | ✅ clangd | ✅ | via LSP | — | ❌ |
| **go**     | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ delve + dap-go |
| markdown   | ✅ | ❌ | ❌ | ❌ | ⚠️ see 1.3 | — |
| bash       | ✅ | ❌ | ❌ | ❌ | ❌ | — |
| html       | ✅ | ❌ | ❌ | ❌ | ❌ | — |
| toml       | ✅ | ❌ | ❌ | ❌ | ❌ | — |
| **yaml / json** | ❌ | ❌ | ❌ | ❌ | ❌ | — |
| **js / ts** | ❌ | ❌ | ❌ | ❌ | ❌ | — |

What falls out of it:

- **Go is the loudest gap.** `kickstart.plugins.debug` is enabled and configures
  `delve` + `nvim-dap-go` — so the config commits to debugging Go, but there is
  no `gopls` entry, no `go` parser in the explicit list, no `gofumpt`/`goimports`
  in `formatters_by_ft`, and no `golangci-lint` in `linters_by_ft`. You can
  step through Go code you get no completion or formatting for.
- **`cpp` is in the format-on-save whitelist** but has no parser in the explicit
  list (the `servers` table covers it via clangd, so LSP is fine).
- **YAML and JSON have nothing at all** — no parser, no schema-aware LSP
  (`yamlls`/`jsonls`), no formatter. For anything with CI files, k8s manifests
  or `docker-compose.yml`, this is the most-felt missing piece after Go.
- **bash / html / toml get syntax highlighting and nothing else** — parsers with
  no `bashls`, no `taplo`, no `shellcheck`, no `shfmt`.
- **Formatting is thinner than it looks.** `default_format_opts.lsp_format =
  'fallback'` means any filetype whose server can format gets it — but only the
  five filetypes in the `format_on_save` whitelist ever format automatically.
  `<leader>f` works everywhere; saving only formats those five.
- **DAP covers one language.** No `nvim-dap-python`, no `codelldb` adapter for
  Rust/C/C++, despite Rust and C being first-class everywhere else in the config.

⚠️ **Accuracy note on parsers:** the `FileType` autocmd at `init.lua:1022-1042`
auto-installs any available parser on first open, so missing parsers *self-heal*.
The real cost is a one-time install pause the first time you open such a file,
plus a startup list that no longer reflects what the config actually targets —
not broken highlighting.

---

## Tier 3 — Workflow features that are simply absent

Nothing here is broken; these are the things a daily-driver setup usually has and
this one doesn't.

**Editing / options** (Section 1, `init.lua:91-174`)
- **No indent defaults.** `tabstop`, `shiftwidth`, `softtabstop`, `expandtab` are
  never set. `guess-indent` handles files with existing content, but a brand-new
  empty file falls back to Vim's 8-wide hard tabs.
- **No folding at all.** The treesitter foldexpr is commented out
  (`init.lua:1010-1011`) and `foldlevel` / `foldenable` / `foldcolumn` /
  `foldmethod` appear nowhere. Large files have no structural collapse.
- **No spell checking**, despite markdown having both a parser and a linter.
- **No wrap/linebreak handling** for prose filetypes.

**Keymaps** (Section 2)
- Missing the usual staples: buffer next/prev (`[b`/`]b`), buffer delete,
  quickfix/loclist navigation (`[q`/`]q`), window resizing, move-lines in visual
  mode, terminal toggle.
- **Namespace collision worth knowing about:** `<leader>b` and `<leader>B` are
  taken by DAP breakpoints (`debug.lua`), so the conventional `<leader>b` =
  "buffer" prefix isn't available. Neither is registered in which-key, so the
  DAP keymaps (`<F1>`–`<F7>`, `<leader>b`) are undiscoverable.

**Missing plugin categories**
- **Session persistence** — nothing restores open buffers/layout per project.
- **Terminal integration** — builtin `:terminal` only; no toggleable terminal.
- **Git beyond the gutter** — gitsigns only. No fugitive/neogit, no diffview, no
  lazygit float. Merge conflicts and history browsing happen outside nvim.
- **No buffer/tab line** — mini.statusline is set up, but there's no visual
  buffer list; `<leader><leader>` (telescope buffers) is the only way to see them.
- **No treesitter textobjects** — `mini.ai` gives you `a)`/`i"` etc., but not
  `af`/`if` (function) or `ac`/`ic` (class), which need
  `nvim-treesitter-textobjects`.
- **No undo tree** visualisation, despite `undofile = true`.
- **No quick-file jumping** (harpoon/grapple-style) for the 3–4 files you bounce
  between in a task.
- **No AI/completion assist** — blink.cmp sources are `{ 'lsp', 'path',
  'snippets' }` only; no buffer source either, so no completion from words in
  open files.
- **`friendly-snippets` is commented out** (`init.lua:917-918`), so LuaSnip is
  running with zero snippets loaded. The snippet engine is installed, wired into
  blink, and empty.

**Telescope gaps** (Section 5) — good coverage already, but no `git_files`,
`git_status`, `git_commits`, marks, or registers pickers.

---

## Tier 4 — Free wins: `mini.nvim` is fully installed, four modules used

`init.lua:407` installs the **whole** `mini.nvim` collection. Only `mini.icons`,
`mini.ai`, `mini.surround` and `mini.statusline` are set up. Everything below is
already on disk at zero added dependency — one `require().setup()` each:

| Module | Fills the gap |
|---|---|
| `mini.pairs` | Auto-close brackets — `kickstart.plugins.autopairs` is disabled at `init.lua:1062` |
| `mini.tabline` | The missing buffer line |
| `mini.files` | Fast edit-the-filesystem-as-a-buffer explorer alongside neo-tree |
| `mini.diff` | Inline diff overlay |
| `mini.move` | Move lines/selections with `alt-hjkl` |
| `mini.sessions` | Session persistence |
| `mini.bufremove` | Delete a buffer without destroying the window layout |
| `mini.splitjoin` | Toggle single-line ↔ multi-line arg lists |
| `mini.trailspace` | Highlight + strip trailing whitespace |

---

## Tier 5 — Structural / performance notes

- **Everything loads eagerly.** `vim.pack.add` is synchronous, and all ten `do`
  blocks run at startup — DAP + dap-ui + mason-nvim-dap, LuaSnip, telescope +
  fzf-native, mason, all of mini.nvim. There is no lazy loading anywhere in the
  config. Measured by running this config headless, startup is ~190ms, with
  `kickstart.plugins.debug` alone accounting for ~32ms — you pay the full
  debugger cost on every `nvim somefile.md`. Deferring DAP behind its first
  keypress is the single biggest available win.
- **Two colorschemes are installed and configured** (`tokyonight` at
  `init.lua:385` and `gruvbox` at `393`); only gruvbox is loaded. Also
  `require('gruvbox').setup {}` passes no options — no `contrast`, and
  `vim.o.background` is never set, so you get whatever the default is rather than
  a deliberate light/dark choice.
- **`system_provided`** (`init.lua:826`) opts `rust_analyzer` and `clangd` out of
  Mason and onto `$PATH`. This is a good call, but it's a silent dependency on
  the machine — worth a `vim.fn.executable` check with a notify, or at least a
  README line, so a fresh machine fails loudly instead of quietly having no Rust
  LSP.
- **Docs are still upstream kickstart.** `README.md`, `doc/kickstart.txt` and the
  70-line ASCII banner describe kickstart, not this config. Nothing in the repo
  records *your* decisions (why gruvbox, why system-provided rust-analyzer, why
  DAP is Go-only).

---

## Suggested order of attack

1. **Tier 1** — four small fixes, restores features you already wrote (~10 min).
2. **Go + YAML/JSON** — the two real coverage holes in Tier 2.
3. **Tier 4 mini modules** — biggest ratio of capability to effort; nothing to install.
4. **Indent defaults + folding + buffer keymaps** — the daily-friction items.
5. **Lazy-load DAP** — halves startup.
6. Sessions / terminal / git UI — pick by what you actually miss.
