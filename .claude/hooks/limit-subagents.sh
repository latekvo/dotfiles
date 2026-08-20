#!/usr/bin/env bash
#
# limit-subagents.sh — PreToolUse hook that imposes HARD recursion limits on
# Claude Code subagents, which the CLI has no native setting for.
#
# Enforces two things Claude Code cannot configure on its own:
#   1. Depth ceiling: root -> child tier -> leaf tier, and NOTHING deeper.
#   2. Fan-out cap:   each child may spawn at most $MAX_CHILDREN leaves.
#
# Wire it up in ~/.claude/settings.json:
#   { "hooks": { "PreToolUse": [ {
#       "matcher": "Agent|Task",
#       "hooks": [ { "type": "command",
#                    "command": "$HOME/.claude/hooks/limit-subagents.sh" } ] } ] } }
#
# How it works: PreToolUse hooks fire inside subagents too, and the stdin JSON
# carries `agent_id` (stable per subagent for its lifetime) and `agent_type` for
# the CALLER, plus the requested child type in `tool_input.subagent_type`. There
# is no depth field, so depth is bounded structurally by TYPE: the leaf tier
# additionally omits the Agent tool in its own frontmatter as belt-and-suspenders.
#
# Rename the two tiers below to match your agents. Override via env if you like.

set -uo pipefail

CHILD_TIER="${CC_CHILD_TIER:-orchestrator}"   # the "children" — may spawn leaves
LEAF_TIER="${CC_LEAF_TIER:-worker}"           # the "sub-children" — spawn nothing
MAX_CHILDREN="${CC_MAX_CHILDREN:-8}"          # counter is cumulative, never decremented: bounds
                                              # lifetime fan-out, not CLAUDE.md's concurrent ceiling

command -v jq >/dev/null 2>&1 || exit 0       # fail-open if jq is unavailable

IN=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<<"$IN" 2>/dev/null || echo "")
case "$TOOL" in Agent | Task) ;; *) exit 0 ;; esac  # only gate subagent spawns

CALLER_ID=$(jq -r '.agent_id // ""'             <<<"$IN" 2>/dev/null || echo "")  # empty => root
CALLER_TYPE=$(jq -r '.agent_type // ""'         <<<"$IN" 2>/dev/null || echo "")
CHILD=$(jq -r '.tool_input.subagent_type // ""' <<<"$IN" 2>/dev/null || echo "")
SESSION=$(jq -r '.session_id // "none"'         <<<"$IN" 2>/dev/null || echo "none")

deny() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Root (main conversation): may only start the child tier.
if [[ -z "$CALLER_ID" ]]; then
  [[ "$CHILD" == "$CHILD_TIER" ]] || deny "Root may only spawn '$CHILD_TIER' subagents (requested '$CHILD')."
  exit 0
fi

# A child: may spawn ONLY leaves, and at most $MAX_CHILDREN of them.
if [[ "$CALLER_TYPE" == "$CHILD_TIER" ]]; then
  [[ "$CHILD" == "$LEAF_TIER" ]] || deny "'$CHILD_TIER' may only spawn '$LEAF_TIER' subagents (requested '$CHILD'); nesting stops here."

  STORE="${TMPDIR:-/tmp}/cc-subagent-limits/$SESSION"
  mkdir -p "$STORE"
  LOCK="$STORE/.lock.$CALLER_ID"
  CTR="$STORE/count.$CALLER_ID"

  # portable mkdir spin-lock (macOS has no flock) around the read-modify-write
  for _ in $(seq 1 100); do
    mkdir "$LOCK" 2>/dev/null && break || sleep 0.05
  done

  count=0
  [[ -f "$CTR" ]] && count=$(cat "$CTR" 2>/dev/null || echo 0)
  if ((count >= MAX_CHILDREN)); then
    rmdir "$LOCK" 2>/dev/null || true
    deny "Fan-out limit reached: '$CHILD_TIER' ($CALLER_ID) already spawned $MAX_CHILDREN sub-children."
  fi
  echo $((count + 1)) >"$CTR"
  rmdir "$LOCK" 2>/dev/null || true
  exit 0
fi

# Any other tier is not permitted to nest further.
deny "Subagent type '$CALLER_TYPE' is not permitted to spawn nested subagents."
