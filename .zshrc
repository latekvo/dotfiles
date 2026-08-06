# Homebrew comes first: tmux, rbenv and the rest of the toolchain live there, and the
# tmux hand-off below has to be able to find tmux. /etc/zprofile's path_helper does not
# add Homebrew, so without this the guard below silently never fires.
if [[ $(uname) == "Darwin" ]]; then
	export PATH="/opt/homebrew/bin:$PATH"
fi

# Start every interactive terminal inside its own tmux session. The guards skip the
# shells tmux would break or nest inside: shells already under tmux, non-interactive
# shells (scripts, agent tooling), shells with no tty, and `dumb` terminals. Set
# NO_TMUX=1 to launch a plain shell.
#
# This sits at the top of the file so the outer shell hands off immediately. tmux
# starts its pane as a login shell, so everything below runs there anyway; doing it
# before the hand-off would build an environment that is discarded by the exec.
#
# The session belongs to the window: destroy-unattached reaps it when the window
# closes and takes its client with it, and @window_session tells the hooks in
# ~/.tmux.conf to re-arm that whenever a window picks the session up again.
# Detaching with the prefix key (see the same file) is the way to park one and keep it.
if command -v tmux >/dev/null 2>&1 \
	&& [[ -o interactive ]] && [[ -t 1 ]] \
	&& [[ -z "$TMUX" ]] && [[ -z "$NO_TMUX" ]] && [[ "$TERM" != "dumb" ]]; then
	exec tmux new-session \; set @window_session 1 \; set destroy-unattached on
fi

# Several blocks below prepend to PATH unconditionally; keep the duplicates out.
typeset -U path PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export COLORTERM=truecolor

# Skip oh-my-zsh's per-startup completion-dir security audit (multi-hundred-ms hit)
ZSH_DISABLE_COMPFIX="true"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="essembeh"

# Makes _ and - interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Compilation flags - might set to auto recognized arch, might add -march
# export ARCHFLAGS="-arch x86_64"

# Uncomment the following line to display red dots whilst waiting for completion.
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
COMPLETION_WAITING_DOTS="true"

# Disable marking untracked files under VCS as dirty. 
# This makes repository status check for large repositories much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# oh-my-zsh's precmd reports the cwd to the terminal with OSC 7, but tmux absorbs
# that sequence into #{pane_path} rather than passing it on, so the terminal
# emulator never learns where the shell moved to and opens every new window in
# the directory its tmux session was created in. Send a second copy wrapped in
# tmux's DCS passthrough, which tmux unwraps and forwards to the terminal; the
# protocol requires every ESC inside the wrapper to be doubled, and the receiving
# end is allow-passthrough in ~/.tmux.conf. omz_termsupport_cwd is undefined over
# SSH, inside Emacs and on terminals that mishandle OSC 7, so there is nothing to
# forward in those cases.
if [[ -n "$TMUX" ]] && (( $+functions[omz_termsupport_cwd] )); then
	_tmux_forward_osc7() {
		local seq
		seq="$(omz_termsupport_cwd)" || return 0
		printf '\ePtmux;%s\e\\' "${seq//$'\e'/$'\e\e'}"
	}
	add-zsh-hook precmd _tmux_forward_osc7
fi

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

export EDITOR='vim'

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ALIASES

# gh
alias cleanele="git clean -fdX" 
alias nukele="git reset --hard && git clean -fd" 

# dots & 中文 
alias 。="."
alias 。。=".."
alias 。。。="..."
alias …="..."
alias ……="......"
alias 在家="cd ~"
alias 上在="cd"

# ios
alias bibepi="cd ios; cd macos; pod install; bundle ins; bundle ex pod install" 
alias bebi="bibepi" 
alias xbebi="cd ios;xed .;bibepi" 

# yarn
alias y="yarn"
alias ys="yarn start"

# yarn + fabric / yarn + paper
alias f0y="FABRIC_ENABLED=0 yarn"
alias f0ys="FABRIC_ENABLED=0 yarn start"
alias f1y="FABRIC_ENABLED=1 yarn"
alias f1ys="FABRIC_ENABLED=1 yarn start"

# term
alias c="clear"
alias cr="clear"

# python & conda
alias pac="source .venv/bin/activate" 
alias cac="conda activate" 

# package size diag
alias atlasprod="EXPO_UNSTABLE_ATLAS=true npx expo start --no-dev"
alias atlasdev="EXPO_UNSTABLE_ATLAS=true npx expo start --no-dev"

# perma enable yolo mode + default to xhigh effort (still overridable per-session via /effort)
alias claude="claude --dangerously-skip-permissions --effort xhigh"
alias agy="agy --dangerously-skip-permissions"

# kill all processes using given port
alias killport='f(){ kill -9 $(lsof -t -i tcp:$1); }; f'

# 1. create branch $1, 2. create worktree for that branch, 3. switch to the worktree
alias add_worktree='f(){ b="$1"; p=$(basename "$PWD"); c=${b//@/}; d="../${p}-worktrees/$c"; git show-ref --verify --quiet refs/heads/"$b" || git branch "$b" main; git worktree add "$d" "$b"; cd "$d"; }; f'

# basically remove file changes from branch
alias resmain='git restore --source=origin/main --staged --worktree'

# MACOS ONLY
if [[ $(uname) == "Darwin" ]]; then
	# android studio
	export PATH="/Applications/Android Studio.app/Contents/MacOS:$PATH"		

	# ruby environment. rbenv is a Homebrew install; ~/.rbenv holds only the shims,
	# which rbenv init puts on PATH itself. .zprofile already runs this for login
	# shells, so only pay for it when the shims are missing - i.e. in a non-login
	# interactive shell. --no-rehash skips a `rbenv rehash` subprocess per startup.
	if [[ ":$PATH:" != *":$HOME/.rbenv/shims:"* ]]; then
		eval "$(rbenv init - --no-rehash zsh)"
	fi

	# ruby
	export GEM_HOME=$HOME/.gem

	# add android SDK to path
	export ANDROID_HOME=/Users/ignacylatka/Library/Android/sdk

	# add JDK to PATH
	export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

	# perhaps bash compatibility - likely to be removed
	export PATH=$HOME/.local/bin:/usr/local/bin:$PATH
fi
export PATH=$PATH:$HOME/.maestro/bin

# Added by Antigravity
export PATH="/Users/ignacylatka/.antigravity/antigravity/bin:$PATH"

# Added by Windsurf
export PATH="/Users/ignacylatka/.codeium/windsurf/bin:$PATH"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# bun completions
[ -s "/Users/ignacylatka/.bun/_bun" ] && source "/Users/ignacylatka/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH=/Users/ignacylatka/.opencode/bin:$PATH

export NVM_DIR="$HOME/.nvm"
# Sourcing nvm.sh in its default mode runs a full `nvm use <default>` on every shell,
# which costs ~600ms of a ~850ms startup. --no-use skips that; the default version goes
# on PATH directly below, which is what the auto-use was there to achieve. `nvm use
# <version>` still switches versions inside a session.
if [ -s "$NVM_DIR/nvm.sh" ]; then
	() {
		[[ -r "$NVM_DIR/alias/default" ]] || return
		local want=$(<"$NVM_DIR/alias/default")
		# one level of indirection resolves aliases like `lts/jod` to a version
		[[ -r "$NVM_DIR/alias/$want" ]] && want=$(<"$NVM_DIR/alias/$want")
		# exact match first, else the numerically highest install under that prefix
		local -a found=(
			"$NVM_DIR/versions/node/$want"(N/)
			"$NVM_DIR/versions/node/v$want"(N/)
			"$NVM_DIR/versions/node/v$want."*(N/n)
		)
		(( $#found )) && path=( "${found[-1]}/bin" $path )
	}
	\. "$NVM_DIR/nvm.sh" --no-use
fi
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

alias argent_install_branch="$HOME/argent-install-branch.sh"
alias prettier_branch="$HOME/prettier-branch.sh"
alias code_branch="$HOME/code-branch.sh"

# cd into the worktree backing a branch name or PR number (PR lookup via gh on software-mansion/argent)
cd_branch() {
  local arg="${1:-}"
  if [ -z "$arg" ]; then
    echo "Usage: cd_branch <branch-name|pr-number>" >&2
    return 1
  fi
  local repo="$HOME/dev/argent"
  if [ ! -d "$repo/.git" ]; then
    echo "Error: argent repo not found at $repo" >&2
    return 1
  fi
  local branch="$arg"
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    branch=$(gh -R software-mansion/argent pr view "$arg" --json headRefName -q .headRefName 2>/dev/null)
    if [ -z "$branch" ]; then
      echo "Error: could not resolve PR #$arg to a branch." >&2
      return 1
    fi
  fi
  local wt
  wt=$(git -C "$repo" worktree list --porcelain | awk -v b="refs/heads/$branch" '
    /^worktree / { w = substr($0, 10) }
    /^branch /   && $2 == b { print w; exit }
  ')
  if [ -z "$wt" ]; then
    echo "Error: no existing worktree for branch '$branch' in $repo." >&2
    return 1
  fi
  cd "$wt"
}

# Ollama: raise the default context for all models. gemma4 (silver:e4b, gemma4:e4b)
# defaults to num_ctx=4096; agent harnesses (OpenCode, etc.) send long system+tools
# that overflow it, so Ollama truncates the input and the model emits degenerate
# "TheThe..." output until max tokens. 32768 fits harness payloads. Restart `ollama
# serve` after sourcing this for it to take effect.
export OLLAMA_CONTEXT_LENGTH=32768

# Added by Antigravity CLI installer
export PATH="/Users/ignacylatka/.local/bin:$PATH"
