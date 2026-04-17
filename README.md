# tmux-claude-session

Tmux plugin that exposes the active pane's [Claude Code](https://docs.anthropic.com/en/docs/claude-code) session as a format placeholder, so you can embed it in your status line, window names, or pane borders. Also provides a keybinding to launch a fresh Claude session in a new window.

## What it does

- Adds a `#{claude_session}` placeholder usable inside any tmux format option.
- Walks the active pane's process tree, looks up `~/.claude/sessions/<pid>.json`, and prints the session `name` (or the first 8 chars of its `sessionId`).
- Falls back to the window's current name (`#W`) — or whatever you configure — when no claude process is running in the pane.
- Integrates with [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect): on save, rewrites each pane's `claude` command to `claude --resume <sessionId>` so restore picks up the conversation instead of starting fresh.

## Install

### With [tpm](https://github.com/tmux-plugins/tpm)

```tmux
set -g @plugin 'xbenng/tmux-claude-session'
```

Then press `prefix + I` to install.

### Manual

```sh
git clone https://github.com/xbenng/tmux-claude-session ~/.tmux/plugins/tmux-claude-session
run-shell ~/.tmux/plugins/tmux-claude-session/claude-session.tmux
```

## Usage

Reference `#{claude_session}` inside any format option. The plugin substitutes it at load time.

```tmux
# Show the claude session (or window name) in each window tab
set -g window-status-format         ' #I:#{claude_session} '
set -g window-status-current-format ' #I:#{claude_session} '

# Or put it in the status line
set -g status-right '#{claude_session} | %H:%M'
```

Make sure `status-interval` is reasonable (e.g. `set -g status-interval 2`) so the placeholder refreshes.

## Options

| Option | Default | Description |
| --- | --- | --- |
| `@claude-session-fallback` | `#W` | Text shown when no claude process is found in the pane tree. |
| `@claude-session-resurrect` | `on` | Register the tmux-resurrect post-save hook. Set to any other value to disable. |

The sessions directory can be overridden via the `CLAUDE_SESSIONS_DIR` env var if claude's data dir is non-standard.

## How it works

When claude starts, it writes `~/.claude/sessions/<pid>.json` containing its `sessionId` and (optional) `name`.

**Format placeholder:** the plugin walks up from `#{pane_pid}` via `ps -o ppid=`, checks for a matching file at each hop, and prints the name (or short sessionId). The walk terminates quickly because `#{pane_pid}` is the top-level process tmux spawned in the pane.

**Resurrect integration:** when tmux-resurrect writes its save file, the post-save hook scans every pane whose command is `claude`, resolves the sessionId from the same manifest files, and edits the saved command line to inject `--resume <sessionId>`. On restore, tmux-resurrect replays the rewritten command and Claude Code resumes the conversation. Requires [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) to be installed; the hook is a no-op otherwise.

## Requirements

- tmux 2.9+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- `bash`, `ps`, `grep` (standard on Linux/macOS)

## License

MIT
