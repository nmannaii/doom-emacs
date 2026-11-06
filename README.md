# doom-emacs

My [Doom Emacs](https://github.com/doomemacs/doomemacs) config: LazyVim-style
keys, Org notes that read like documents, C# with Roslyn and a debugger, and
Claude Code inside Emacs. Works on Linux and Windows.

## Install

### Linux

```bash
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
git clone git@github.com:nmannaii/doom-emacs.git ~/.config/doom
~/.config/emacs/bin/doom install
```

### Windows

From Git Bash:

```bash
winget install GNU.Emacs Git.Git BurntSushi.ripgrep.MSVC sharkdp.fd
setx HOME "%USERPROFILE%"          # then reopen the terminal
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
git clone git@github.com:nmannaii/doom-emacs.git ~/.config/doom
~/.config/emacs/bin/doom install
```

On Windows the config switches by itself: the terminal is eshell and Claude
Code runs in `eat` (vterm can't be built there), and Claude starts with plain
`claude`.

### Fonts

- JetBrainsMono Nerd Font (code)
- Noto Sans (prose in Org files)

### Updating

```bash
cd ~/.config/doom && git pull && ~/.config/emacs/bin/doom sync
```

Then restart Emacs.

## Optional tools

Each one turns on a feature; everything else works without them.

| Tool | For | Install |
| --- | --- | --- |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Claude inside Emacs | see its docs |
| `roslyn-language-server` | C# completion, references, rename | `dotnet tool install -g roslyn-language-server` |
| [netcoredbg](https://github.com/Samsung/netcoredbg/releases) | C# debugging | unpack into `~/.config/doom/debug-adapters/netcoredbg/`, or put it on PATH |
| `mmdc` | Mermaid diagrams in Org | `npm i -g @mermaid-js/mermaid-cli` |
| `pandoc` | Exporting Org to HTML, PDF, Word | your package manager |
| LaTeX + `dvipng` | Math previews in Org | your TeX distribution |

## Files

| File | What's in it |
| --- | --- |
| `init.el` | Doom modules |
| `packages.el` | Extra packages |
| `config.el` | Theme, fonts, LSP (incl. the Roslyn client and solution picker) |
| `keys.el` | Keybindings (Neovim/LazyVim style) |
| `docs.el` | Org, markdown and vimwiki behaviour: agenda, capture, Mermaid, pandoc export |
| `org-pretty.el` | How Org files look: headings, fonts, page column, LaTeX |
| `ide.el` | C# debugging and editing, Roslyn progress, Claude Code |

## Keys worth knowing

Leader is `SPC`. `SPC ?` lists the keys for the current buffer.

### General

| Key | Does |
| --- | --- |
| `C-h/j/k/l` | Move between windows |
| `C-/` | Terminal popup (one per workspace) |
| `SPC e` | File tree |
| `SPC f o` | Notes folder (`~/org`) |
| `SPC TAB …` | Workspaces |
| `C-=` / `C--` / `C-+` | Bigger / smaller / reset text (normal mode) |

### Org

| Key | Does |
| --- | --- |
| `SPC t O` | Raw ↔ document view |
| `SPC t o` | Page column on/off |

### C#

| Key | Does |
| --- | --- |
| `gr` / `gd` | References / definition |
| `SPC c P` | Pick which solution Roslyn loads (`.slnx` or a `.slnf` filter) |
| `F5` | Start debugging (pick launch or attach) / continue |
| `F10` / `F11` / `S-F11` | Step over / into / out |
| `SPC d b` | Breakpoint |
| `vaf` / `vif`, `]f` / `[f` | Select a function / jump between functions |

### Claude Code

| Key | Does |
| --- | --- |
| `SPC a c` or `C-'` | Show or hide this project's Claude (starts one if none) |
| `SPC a C` | Another Claude for the same project |
| `SPC a i` | Send the selection to Claude |
| `SPC a l` | All running Claude sessions |
| `Esc` / `C-Esc` | In Claude: Esc goes to Claude; Ctrl-Esc leaves insert mode |
