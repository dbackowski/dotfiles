# dotfiles

| path | installs to | app |
| --- | --- | --- |
| `claude/` | `~/.claude/` | Claude Code — settings, hooks, statusline, commands |
| `ghostty/` | `~/.config/ghostty/` | Ghostty |
| `lvim/` | `~/.config/lvim/` | LunarVim |
| `sublime-text/` | Sublime `Packages/User/` | Sublime Text |
| `tmux/` | `~/` | tmux overrides for [oh-my-tmux](https://github.com/gpakosz/.tmux) |
| `vscode/` | VS Code `User/` | VS Code |

Copied into place by hand, not symlinked — edits in either direction need copying back.

## tmux

`tmux/.tmux.conf.local` → `~/.tmux.conf.local`. Requires oh-my-tmux cloned to
`~/.tmux/`, which sources it and reads its `tmux_conf_theme_*` variables. Reload with
`tmux source-file ~/.tmux.conf`.

Window tabs show Claude Code session state — yellow `claude *` working, green
`claude ✓` finished (grey once you've visited it), red `claude !` blocked on a
permission prompt. Written per pane by `claude/tmux-cc-state.sh`, wired up by the
hooks in `claude/settings.json`; both belong in `~/.claude/`.
