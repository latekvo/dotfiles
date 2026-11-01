#!/usr/bin/env python3
"""PreToolUse(Bash): block pkill/pgrep with an option after the pattern.

BSD pkill/pgrep stop option parsing at the first operand, so in
`pkill -f "sleep 900" -U 501 -P 1` the "-U", "501", "-P", "1" become extra
patterns and -f "1" matches nearly every process on the machine.
"""
import json
import os
import shlex
import sys

TOOLS = {"pkill", "pgrep"}
TAKES_ARG = set("FGgPstUuJ")
SEPARATORS = {";", "&&", "||", "|", "&", "(", ")", "\n", "|&"}


def offending(command):
    lex = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
    lex.whitespace_split = True
    lex.commenters = ""
    try:
        tokens = list(lex)
    except ValueError:
        return None
    i = 0
    while i < len(tokens):
        if os.path.basename(tokens[i]) not in TOOLS:
            i += 1
            continue
        tool, i, operand_seen = tokens[i], i + 1, False
        while i < len(tokens) and tokens[i] not in SEPARATORS:
            tok = tokens[i]
            if tok == "--" and not operand_seen:
                operand_seen = True  # everything after -- is a pattern by design
                i += 1
                while i < len(tokens) and tokens[i] not in SEPARATORS:
                    i += 1
                break
            if tok.startswith("-") and len(tok) > 1:
                if operand_seen:
                    return f"{tool}: option {tok!r} after the pattern"
                if tok[-1] in TAKES_ARG and len(tok) == 2:
                    i += 1
            else:
                operand_seen = True
            i += 1
    return None


def main():
    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    problem = offending(command)
    if problem:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"Blocked {problem}. BSD pkill/pgrep treat every argument after "
                "the first pattern as another pattern, so trailing flags and their "
                "values (e.g. `-P 1`) match almost every process. Put all options "
                "before the pattern: `pkill -U 501 -P 1 -f 'sleep 900'`."),
        }}))


main()
