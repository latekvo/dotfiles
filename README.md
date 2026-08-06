# dotfiles

Config for zsh, tmux, vim, Claude Code, alacritty, awesome and qt6ct, shared
between a macOS machine and an Arch/XFCE one.

## Install

```sh
./install.sh              # link everything; refuse to touch conflicts
./install.sh --dry-run    # print the plan, change nothing
./install.sh --force      # back conflicts up under ~/.dotfiles-backup/, then link
./install.sh --status     # report only; exit 1 if anything is unlinked
```

Every git-tracked path starting with a dot is symlinked into `$HOME`. `git add`
is therefore the whole of "start managing this file", and repo-only files
(`install.sh`, this README) stay out of `$HOME` on their own.

Symlinks rather than copies, deliberately: a copy-based install is what let this
repo rot. Files were edited in `$HOME` and in the repo independently until 14 of
16 tracked files had diverged **in both directions**, and `.tmux.conf` — committed
in `f39820a` — turned out never to have been deployed at all, so the tmux session
hooks it defines had never once run on the Linux box.

Run `./install.sh --status` if config starts behaving oddly. An application that
replaces a file rather than writing it in place (rather than editing through the
link) leaves a real file where a symlink should be; re-running the installer
restores it.

## Cross-machine notes

- `.zshrc` guards its Homebrew and Android/Java `PATH` blocks behind
  `uname == Darwin`; the `xed` and CocoaPods aliases are macOS-only but inert
  elsewhere.
- `.tmux.conf` keys extended-key support off the `xterm*` pattern. Both terminals
  in use report `xterm-256color` — iTerm2 on macOS, xfce4-terminal (VTE) on Linux
  — so the pattern matches in both places, but only the iTerm2 half is confirmed
  to honour the request.

## `.claude/hooks/limit-subagents.sh` is not wired up

The script is tracked and deployed, but `.claude/settings.json` does **not**
reference it, because with `jq` installed the hook denies every subagent spawn:

```
$ echo '{"tool_name":"Agent","agent_id":"","agent_type":"",
         "tool_input":{"subagent_type":"Explore"},"session_id":"t"}' \
    | .claude/hooks/limit-subagents.sh
{"...","permissionDecision":"deny",
 "permissionDecisionReason":"Root may only spawn 'orchestrator' subagents (requested 'Explore')."}
```

It restricts the root conversation to spawning one agent type, `CHILD_TIER`,
which still holds its placeholder value of `orchestrator`; no agent by that name
(or by `worker`, the leaf tier) is defined in this repo or in either `$HOME`. Its
own header says to rename the tiers to match your agents, and that was never
done. The hook fails open only where `jq` is missing, which is what hid this.

To turn it on: define the two tiers as real agents under `.claude/agents/`, or
point `CHILD_TIER`/`LEAF_TIER` at existing ones, then add back to
`.claude/settings.json`:

```json
"hooks": {
  "PreToolUse": [
    { "matcher": "Agent|Task",
      "hooks": [ { "type": "command",
                   "command": "$HOME/.claude/hooks/limit-subagents.sh" } ] } ]
}
```
