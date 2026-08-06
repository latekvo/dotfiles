#!/usr/bin/env bash
#
# install.sh — link every tracked dotfile into $HOME.
#
# Symlinks, not copies. A copy-based install is what let this repo rot: files
# were edited in $HOME and in the repo independently, and by the time anyone
# looked, 14 of 16 tracked files had diverged in both directions and one
# committed file (.tmux.conf) had never been deployed at all. A symlink makes
# the repo and the live config the same bytes, so committing is the only way to
# save a change and there is nothing left to forget.
#
#   ./install.sh              link everything; refuse to touch conflicts
#   ./install.sh --dry-run    print the plan, change nothing
#   ./install.sh --force      back conflicts up, then link them
#   ./install.sh --status     report only; exit 1 if anything is unlinked
#
# What counts as a dotfile: every git-tracked path starting with a dot. That
# keeps repo-only files (this script, README.md) out of $HOME automatically and
# means `git add` is the whole of "start managing this file".
#
# Conflicts (a real file in $HOME whose bytes differ from the repo's) are never
# overwritten silently. Without --force they are skipped and the script exits 1;
# with --force the existing file is copied under ~/.dotfiles-backup/<stamp>/
# first. A file that is already byte-identical is adopted without a backup,
# since there is nothing to lose.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.dotfiles-backup"

DRY=0 FORCE=0 STATUS=0
for arg in "$@"; do
	case "$arg" in
	--dry-run) DRY=1 ;;
	--force) FORCE=1 ;;
	--status) STATUS=1 DRY=1 ;;
	-h | --help)
		sed -n '3,26p' "${BASH_SOURCE[0]}" | sed -e 's/^#$//' -e 's/^# //'
		exit 0
		;;
	*)
		echo "install.sh: unknown option '$arg'" >&2
		exit 2
		;;
	esac
done

cd "$REPO" || exit 1
command -v git >/dev/null || {
	echo "install.sh: git is required" >&2
	exit 2
}

# One backup directory per run, created only if something actually needs one.
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
backup() {
	mkdir -p "$BACKUP/$(dirname "$1")"
	cp -pR "$HOME/$1" "$BACKUP/$1" # -pR, not -a: BSD cp predates -a
}

linked=0 adopted=0 already=0 conflict=0 restored=0

while IFS= read -r f; do
	case "$f" in .*) ;; *) continue ;; esac # tracked, and a dotfile
	src="$REPO/$f" dst="$HOME/$f"

	# Plain readlink, compared against the absolute path this script links to.
	# `readlink -f` is GNU-only — BSD/macOS readlink rejects it, and the error
	# leaves both sides of the comparison empty, so every symlink would compare
	# equal and a link pointing somewhere else would be reported as correct.
	if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
		((already++))
		[[ $STATUS -eq 1 ]] && printf '  ok        %s\n' "$f"
		continue
	fi

	if [[ -e "$dst" || -L "$dst" ]]; then
		if [[ ! -L "$dst" ]] && cmp -s "$src" "$dst"; then
			verb="adopt " # identical bytes: relinking loses nothing
			((adopted++))
		elif [[ $FORCE -eq 1 ]]; then
			verb="replace"
			((restored++))
		else
			printf '  CONFLICT  %s  (differs from repo; --force to back up and link)\n' "$f"
			((conflict++))
			continue
		fi
	else
		verb="link  "
		((linked++))
	fi

	printf '  %s    %s\n' "$verb" "$f"
	[[ $DRY -eq 1 ]] && continue

	[[ "$verb" == "replace" ]] && backup "$f"
	mkdir -p "$(dirname "$dst")"
	rm -rf "$dst"
	ln -s "$src" "$dst"
done < <(git ls-files)

echo
printf 'linked %d · adopted %d · replaced %d · already linked %d · conflicts %d\n' \
	"$linked" "$adopted" "$restored" "$already" "$conflict"
[[ $restored -gt 0 && $DRY -eq 0 ]] && echo "backups: $BACKUP"
[[ $DRY -eq 1 ]] && echo "(dry run — nothing changed)"

# Non-zero on unresolved conflicts, and on --status if anything is not linked,
# so this is usable as a check rather than only as an installer.
if [[ $conflict -gt 0 ]]; then exit 1; fi
if [[ $STATUS -eq 1 && $((linked + adopted + restored)) -gt 0 ]]; then exit 1; fi
exit 0
