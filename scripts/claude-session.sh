#!/usr/bin/env bash
# Print the Claude Code session name (or short sessionId) whose process
# is nested inside the pane rooted at $1. Prints $2 as a fallback when
# no claude process is found. Invoked by the plugin's format substitution;
# see claude-session.tmux.
#
# Walks DOWN the process tree (DFS over descendants) — not up —
# because `claude` is almost always a child of the pane's shell (e.g.
# `zsh → claude`), never an ancestor.
pid="$1"
fallback="$2"
dir="${CLAUDE_SESSIONS_DIR:-$HOME/.claude/sessions}"

emit_fallback() { [ -n "$fallback" ] && printf '%s' "$fallback"; exit 0; }

[ -n "$pid" ] && [ -d "$dir" ] || emit_fallback

# Try one pid: if its session file resolves to a name, print it and exit 0.
# Returns non-zero otherwise.
try_pid() {
    local p="$1" f="$dir/$1.json"
    [ -f "$f" ] || return 1
    local name
    name=$(grep -o '"name":"[^"]*"' "$f" | head -1 | cut -d'"' -f4)
    [ -z "$name" ] && name=$(grep -o '"sessionId":"[^"]*"' "$f" | head -1 | cut -d'"' -f4 | cut -c1-8)
    [ -z "$name" ] && return 1
    printf '%s' "$name"
    exit 0
}

# DFS: check $1, then recurse into each child. Depth is bounded by the real
# process tree so termination is guaranteed.
search() {
    try_pid "$1"
    local child
    for child in $(pgrep -P "$1" 2>/dev/null); do
        search "$child"
    done
}

search "$pid"
emit_fallback
