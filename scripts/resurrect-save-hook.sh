#!/usr/bin/env bash
# tmux-resurrect post-save-layout hook.
#
# For every pane running `claude`, looks up the Claude Code session ID via
# ~/.claude/sessions/<pid>.json and rewrites the saved command from
#   :claude <args...>
# to
#   :claude --resume <sessionId> <args...>
# so that on restore, tmux-resurrect replays the command and Claude Code
# picks up the conversation instead of starting fresh.

RESURRECT_FILE="$1"
SESSIONS_DIR="${CLAUDE_SESSIONS_DIR:-$HOME/.claude/sessions}"

[[ -z "$RESURRECT_FILE" || ! -f "$RESURRECT_FILE" ]] && exit 0
[[ ! -d "$SESSIONS_DIR" ]] && exit 0

read_sid() {
    grep -o '"sessionId":"[^"]*"' "$1" 2>/dev/null | head -1 | cut -d'"' -f4
}

# ── 1. Build mapping: "session_name:window.pane" → claude session ID ──
declare -A SID_MAP

while IFS=$'\t' read -r target pid cmd; do
    [[ "$cmd" != "claude" ]] && continue

    # pane_pid might be claude itself, or a shell with claude as a child.
    session_file="$SESSIONS_DIR/${pid}.json"
    if [[ ! -f "$session_file" ]]; then
        child=$(pgrep -P "$pid" -x claude 2>/dev/null | head -1)
        [[ -n "$child" ]] && session_file="$SESSIONS_DIR/${child}.json"
    fi

    [[ -f "$session_file" ]] || continue

    sid=$(read_sid "$session_file")
    [[ -n "$sid" ]] && SID_MAP["$target"]="$sid"
done < <(tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index}	#{pane_pid}	#{pane_current_command}")

[[ ${#SID_MAP[@]} -eq 0 ]] && exit 0

# ── 2. Rewrite save file: inject --resume <sid> into claude commands ──
tmp=$(mktemp)
while IFS= read -r line; do
    if [[ "$line" == pane$'\t'* ]]; then
        IFS=$'\t' read -ra f <<< "$line"
        # f[1]=session  f[2]=window  f[5]=pane  f[9]=command  f[10]=:full_command
        key="${f[1]}:${f[2]}.${f[5]}"

        if [[ "${f[9]}" == "claude" && -n "${SID_MAP[$key]}" ]]; then
            sid="${SID_MAP[$key]}"
            old="${f[10]}"
            clean=$(printf '%s' "$old" | sed -E 's/ *--resume [0-9a-f-]{36}//')
            new="${clean//:claude /:claude --resume $sid }"
            [[ "$new" == "$clean" ]] && new=":claude --resume $sid"
            f[10]="$new"
        fi

        out="${f[0]}"
        for ((i = 1; i < ${#f[@]}; i++)); do
            out+=$'\t'"${f[$i]}"
        done
        printf '%s\n' "$out"
    else
        printf '%s\n' "$line"
    fi
done < "$RESURRECT_FILE" > "$tmp"

mv "$tmp" "$RESURRECT_FILE"
