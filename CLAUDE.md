# Global Claude Code Instructions

## Hard Constraints

### Worktrees
For repos with collaborators or a shared remote, always implement new features or fixes in a separate git worktree, never in a worktree checked out to the `main` branch — unless the user explicitly says otherwise. For tiny solo single-contributor repos the user maintains alone (personal dotfiles, local experiments, scripts no one else touches), skip the worktree dance and commit straight to `main`. When in doubt — repo has collaborators, a public remote others might consume, or is the "released" branch of an OSS project — default to worktrees and ask. When spawning sub-agents to implement changes, each agent must still receive `isolation: "worktree"` AND must branch from the master agent's current branch, so their work stacks cleanly and merges back without polluting your working directory; this applies even in solo repos.

### Git — Zero AI Attribution
No Claude/AI traces anywhere in git/GitHub: no `Co-Authored-By`, no `--author` overrides, no "Generated with Claude/Claude Code/🤖" taglines. Applies to commits, PR titles/descriptions, issue comments — all git output. Strip these when editing existing PRs/issues. Commit author must always be the user.

### Don't Open PRs Unprompted
Never open a pull request unless the user explicitly asks for one. Branch, commit, and push freely on feature/fix branches, but stop before `gh pr create` and let the user decide when (and how) the PR opens. If they do ask for one, it must be a draft (`--draft`) — never mark a PR ready-for-review on your own.

### Don't Commit to Main on Shared Repos
For any repo with collaborators or a shared remote others consume, never commit or push directly to `main`/`master`. All work happens on isolated feature/fix branches; the only path to main is a PR the user reviews. Don't run `git push origin main`, `git merge` into main, or anything else that modifies the main branch on shared repos.

**Exception:** tiny solo single-contributor repos (personal dotfiles, local-only experiments, scripts no one else touches) — commit directly to main, no branch ceremony required. Solo-but-public projects where `main` is the released branch still need branches and PRs; ask if uncertain whether a repo qualifies as solo.

### Verification Before Reporting Done
Before declaring any task complete, spawn four parallel verification agents and fix all issues they find (re-verify after fixes):
1. **Correctness** — Run tests and build. Write missing tests for changed behavior.
2. **Scope** — Audit the diff against the original request; flag gaps.
3. **Edge cases** — Enumerate edge cases (nulls, boundaries, errors, concurrency) for every changed function; confirm each is handled.
4. **Ripple effects** — Search all callers, references, docs, configs, CI, and tests for changed symbols; flag anything needing updates.

### Maximize Parallelization via Sub-Agents
Dispatch independent work to sub-agents aggressively, including swarms of them. Any task that doesn't require massive shared context or exclusive access to a race-prone resource (a single Android AVD, a single dev port, an in-progress DB migration, an interactive shell session) should be delegated. File searches across the repo, isolated edits to unrelated files, build verifications, independent test suites, multi-file refactors with non-overlapping scope, research and exploration: all of these run faster as parallel sub-agents than serially in the main thread. Default to delegating; reserve the main-thread context for synthesis, decisions, and work that must stay coherent across the whole task. When in doubt, prefer "spawn an agent" over "do it inline" — the cost of an unnecessary agent is small, the cost of unnecessarily serializing parallelizable work is paid against the user's wall-clock time.

### Prove Bugs Before Fixing or Reporting Them
When you find or suspect a bug, prove it exists with a concrete repro or by reading the authoritative source (code, binary strings, protocol spec) — only then fix or report it. Plausible hypotheses, single observations, and second-hand claims from other agents do not clear this bar. After you believe the fix is in place, re-run the original repro end-to-end to confirm the fix lands before you tell the user the work is done.

### Full End-to-End Verification of Features and Fixes
When asked to work on a feature or fix, part of verifying correctness is running the actual feature/fix end-to-end — not just type-checks, unit tests, or static reasoning. Drive the real entry point a real user would (CLI command, alias, HTTP request, UI flow, build pipeline) and confirm the observable behavior matches the requested outcome before reporting done. Static checks pass on broken code constantly; only an E2E run proves the change actually works.

Apply when an E2E run is feasible and not destructive. Skip only when the run requires resources you don't have (production credentials, paid APIs, hardware), would have irreversible side effects on shared systems, or the user has explicitly told you to skip it — and say so explicitly rather than declaring success.

### Linear / Project Management
Never update, reassign, or change the status of any ticket (Linear, Jira, GitHub Issues, etc.) that is assigned to another person. Only create new issues or modify issues that are unassigned or assigned to the current user ("me"). If a ticket belongs to someone else, report its state but do not touch it.

### Verify Prettier and CI Locally Before Done
Before reporting work complete, run the project's formatter (Prettier or equivalent) and any CI-equivalent checks locally (lint, typecheck, tests, build). Don't push and wait for remote CI to surface issues you could have caught locally.

## Coding Behavior

### Reason Hard, Decide Hard
Bring genuine analytical depth to non-trivial decisions — failure modes, second-order effects, fit with existing patterns. The right answer is almost always derivable from context; even forks are yours to resolve. `AskUserQuestion` is not an escape valve for hard decisions.

## Tools & Skills

### Exercising Argent MCP tools from the shell
When working on Argent itself — iterating on a tool's code, repro'ing a bug against a live simulator/emulator, or driving tools from a script/CI — invoke the `argent-local-test` skill. It talks directly to the tool-server's HTTP API (`GET /tools`, `POST /tools/:name`) and bypasses the MCP stdio transport entirely, so calls are synchronous, scriptable, and one `curl` away from a terminal.

The skill ships a helper script at `~/.claude/skills/argent-local-test/scripts/argent-call` with these subcommands: `url`, `status`, `list [--full]`, `schema <tool>`, `call <tool> '<json>'`, `devices`, `logs [-f]`, `kill`. It auto-discovers the running tool-server via `~/.argent/tool-server.json` (written by `argent mcp`) or `$ARGENT_TOOLS_URL`. Dependencies: `curl` + `jq`.

Prefer this over ad-hoc `curl` commands or spinning up an IDE/MCP client when the goal is to repro, verify, or CI-check a single tool. Full usage notes and a CI example live in `~/.claude/skills/argent-local-test/SKILL.md`.
