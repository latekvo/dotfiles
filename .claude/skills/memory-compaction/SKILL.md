---
name: memory-compaction
description: Compress a bloated MEMORY.md memory index back under its load limit. Use when a hook reports the memory index is over the ~24.4KB (24973-byte) load cap, when tail entries are being silently truncated on load, or when the user asks to compact/shrink/trim a MEMORY.md.
---

# Memory compaction

Shrink a project's `MEMORY.md` index so it loads whole. Only `MEMORY.md` counts toward the cap.

## Facts that drive the method
- **Hard cap: 24973 bytes** (~24.4KB). Over it, entries truncate **tail-first, silently**.
- **Only `MEMORY.md` counts.** Individual memory `.md` files are free — deleting them saves **zero** load bytes. Compaction = removing/shortening **index lines**, not files.
- **Dropping an index line ≠ deleting its file.** The `.md` stays on disk, just unindexed (won't load/recall) — fully reversible. Only `rm` true duplicates, and only when asked.
- **Concurrent sessions append to it live.** Re-read immediately before every `Write`; a conflicting `Write` fails with "File has been modified since read" — re-read, merge the new lines, retry.
- Line format: `- [Title](filename.md) - hook`. **Preserve the exact `(filename.md)` link** (that's the recall key). Regular dash separator, **never `—`** (3 bytes + violates the dash rule). ~36 bytes/line is fixed scaffolding, so cutting entry *count* beats trimming hooks.

## Procedure
1. **Find the real file.** It's the project's `.../memory/MEMORY.md`, not necessarily the one in context. `wc -c` it.
2. **Pick a target.** Aim well under the cap — **≤ ~12KB** (or the size the user names) so concurrent appends don't re-truncate. Below ~180 entries you must cut count, not just prose.
3. **Drop (index line only; file stays):**
   - Resolved PR-review snapshots — their reusable nuggets already live in retained sibling entries.
   - `feedback_*` lines that just restate a `~/.claude/CLAUDE.md` rule — CLAUDE.md is always loaded, so these are pure duplication.
   - Niche one-off test/repro gotchas with no recurring value.
   - Dormant old-project clusters → collapse each to a single pointer line.
4. **Keep, tersely:** environment facts, device UDIDs, E2E/fixture recipes, live flake signatures, CI-gate traps, active-work designs. Cut trailing clauses, not the load-bearing nugget.
5. **Re-read, then `Write`** the new index (or targeted `Edit`s). Keep the `# Memory Index` header.
6. **Validate** (below). Report `before → after` bytes and entry count.

## Validate
```bash
cd <memory-dir>
s=$(wc -c < MEMORY.md); echo "bytes=$s  headroom=$((24973-s))  entries=$(/usr/bin/grep -c '^\- \[' MEMORY.md)"
echo "em-dashes: $(/usr/bin/grep -c '—' MEMORY.md)"        # must be 0
/usr/bin/grep -oE '\]\([a-zA-Z0-9_]+\.md\)' MEMORY.md | sed -E 's/\]\((.*)\)/\1/' \
  | while read f; do [ -f "$f" ] || echo "BROKEN LINK: $f"; done   # each link must resolve
/usr/bin/grep -oE '\]\([a-zA-Z0-9_]+\.md\)' MEMORY.md | sort | uniq -d   # must be empty (no dupes)
```
Pass = under cap with headroom, zero em-dashes, every link resolves, no duplicates.
