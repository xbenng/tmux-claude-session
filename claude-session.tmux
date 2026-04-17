#!/usr/bin/env bash
# tmux-claude-session — tmux plugin entry point.
# Replaces #{claude_session} inside status/window format options with a
# shell invocation that resolves the active pane's Claude Code session.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT="$CURRENT_DIR/scripts/claude-session.sh"

PLACEHOLDER='#{claude_session}'

# User-tunable fallback: what to show when no claude process is active.
# Defaults to the window's current name (#W).
fallback_default='#W'
fallback=$(tmux show-option -gqv '@claude-session-fallback')
[ -z "$fallback" ] && fallback="$fallback_default"

# The substitution. #{pane_pid} and the fallback are expanded by tmux
# before the shell runs, so the script receives literal arguments.
replacement="#($SCRIPT #{pane_pid} \"$fallback\")"

# Options that commonly reference window/pane-aware formats.
for opt in \
    status-left \
    status-right \
    window-status-format \
    window-status-current-format \
    window-status-style \
    pane-border-format
do
    value=$(tmux show-option -gqv "$opt")
    case "$value" in
        *"$PLACEHOLDER"*)
            new=${value//"$PLACEHOLDER"/$replacement}
            tmux set-option -g "$opt" "$new"
            ;;
    esac
done

# Keybinding: prefix + C (shift-C) opens a fresh claude session in a new window.
new_key=$(tmux show-option -gqv '@claude-session-new-key')
[ -z "$new_key" ] && new_key='C'
new_cmd=$(tmux show-option -gqv '@claude-session-new-command')
[ -z "$new_cmd" ] && new_cmd='claude'

if [ "$new_key" != '' ] && [ "$new_key" != 'none' ]; then
    tmux bind-key "$new_key" new-window "$new_cmd"
fi

# tmux-resurrect integration: rewrite saved `claude` commands to include
# `--resume <sessionId>` so restore picks up the conversation. No-op unless
# tmux-resurrect is installed and triggers a save.
resurrect_enabled=$(tmux show-option -gqv '@claude-session-resurrect')
[ -z "$resurrect_enabled" ] && resurrect_enabled='on'

if [ "$resurrect_enabled" = 'on' ]; then
    tmux set-option -g @resurrect-hook-post-save-layout \
        "$CURRENT_DIR/scripts/resurrect-save-hook.sh"
fi
