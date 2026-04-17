#!/usr/bin/env bash
# Print the Claude Code session name (or short sessionId) for the process
# tree rooted at $1. Prints $2 as a fallback when no claude process is found.
# Invoked by the plugin's format substitution; see claude-session.tmux.
pid="$1"
fallback="$2"
dir="${CLAUDE_SESSIONS_DIR:-$HOME/.claude/sessions}"

emit_fallback() { [ -n "$fallback" ] && printf '%s' "$fallback"; exit 0; }

[ -n "$pid" ] && [ -d "$dir" ] || emit_fallback

while [ -n "$pid" ] && [ "$pid" != "0" ] && [ "$pid" != "1" ]; do
    f="$dir/$pid.json"
    if [ -f "$f" ]; then
        name=$(grep -o '"name":"[^"]*"' "$f" | head -1 | cut -d'"' -f4)
        if [ -z "$name" ]; then
            name=$(grep -o '"sessionId":"[^"]*"' "$f" | head -1 | cut -d'"' -f4 | cut -c1-8)
        fi
        if [ -n "$name" ]; then
            printf '%s' "$name"
            exit 0
        fi
        emit_fallback
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
emit_fallback
