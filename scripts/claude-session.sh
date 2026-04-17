#!/usr/bin/env bash
# Print the Claude Code session name (or short sessionId) whose process
# is nested inside the pane rooted at $1. Prints $2 as a fallback when
# no claude process is found. Invoked by the plugin's format substitution;
# see claude-session.tmux.
#
# The search walks DOWN the process tree (BFS over descendants) — not up —
# because `claude` is almost always a child of the pane's shell (e.g.
# `zsh → claude`), never an ancestor.
pid="$1"
fallback="$2"
dir="${CLAUDE_SESSIONS_DIR:-$HOME/.claude/sessions}"

emit_fallback() { [ -n "$fallback" ] && printf '%s' "$fallback"; exit 0; }

[ -n "$pid" ] && [ -d "$dir" ] || emit_fallback

# Try one pid: if its session file resolves to a name, print it and exit 0.
# Returns 1 otherwise.
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

# BFS: start at the pane pid, then enqueue each child as we go.
# Depth is bounded by the real process tree (terminates naturally).
queue="$pid"
while [ -n "$queue" ]; do
    head=${queue%% *}
    rest=${queue#"$head"}
    queue=${rest# }
    [ -z "$head" ] && continue
    try_pid "$head"
    # Enqueue children of $head (macOS + Linux both have pgrep -P).
    children=$(pgrep -P "$head" 2>/dev/null || true)
    for c in $children; do
        queue="$queue $c"
    done
done

emit_fallback
