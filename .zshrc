# More glob syntax
setopt extendedglob

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export COLORTERM=truecolor

if [[ $(uname) == "Darwin" ]]; then
  # homebrew has to be first or things break
	export PATH="/opt/homebrew/bin:$PATH"
	export PATH="/Applications/Android Studio.app/Contents/MacOS:$PATH"		

	# ruby env
	if [[ ":$PATH:" != *":$HOME/.rbenv/shims:"* ]]; then
		eval "$(rbenv init - --no-rehash zsh)"
	fi

	# ruby
	export GEM_HOME=$HOME/.gem

	export ANDROID_HOME=/Users/ignacylatka/Library/Android/sdk
	export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

  # bash compat (?)
	export PATH=$HOME/.local/bin:/usr/local/bin:$PATH

  # each session in tmux plus kill unattached sessions
  # usecase: easier programatic interaction with sessions
  if command -v tmux >/dev/null 2>&1 \
    && [[ -o interactive ]] && [[ -t 1 ]] \
    && [[ -z "$TMUX" ]] && [[ -z "$NO_TMUX" ]] && [[ "$TERM" != "dumb" ]]; then
    exec tmux new-session \; set @window_session 1 \; set destroy-unattached on
  fi
fi

if [[ $(uname) == "Linux" ]]; then
	# macOS-style `open`
	alias open='xdg-open'
fi


# Several blocks below prepend to PATH unconditionally; keep the duplicates out.
typeset -U path PATH

# Skip oh-my-zsh's per-startup completion-dir security audit (multi-hundred-ms hit)
ZSH_DISABLE_COMPFIX="true"

ZSH_THEME="essembeh"

# makes _ and - interchangeable.
HYPHEN_INSENSITIVE="true"

ENABLE_CORRECTION="false"
COMPLETION_WAITING_DOTS="false"

# standard plugins can be found in $ZSH/plugins/
# custom plugins may be added to $ZSH_CUSTOM/plugins/
# format: plugins=(rails git textmate ruby lighthouse)
plugins=(git)

source $ZSH/oh-my-zsh.sh

# fix for omz sending precmd that gets cut off under tmux with osc7
if [[ -n "$TMUX" ]] && (( $+functions[omz_termsupport_cwd] )); then
	_tmux_forward_osc7() {
		# The replacement half of ${//} takes $'...' literally, so the doubling
		# that the wrapper depends on has to come from a variable.
		local seq esc=$'\e'
		seq="$(omz_termsupport_cwd)" || return 0
		printf '\ePtmux;%s\e\\' "${seq//$esc/$esc$esc}"
	}
	add-zsh-hook precmd _tmux_forward_osc7
fi

export EDITOR='vim'

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
alias claude-code="claude-code --dangerously-skip-permissions --effort xhigh"
alias agy="agy --dangerously-skip-permissions"

# kill all processes using given port
alias killport='f(){ kill -9 $(lsof -t -i tcp:$1); }; f'

# reap parked tmux sessions that outlived destroy-unattached
alias tmux_kill_unattached="tmux list-sessions -f '#{?session_attached,0,1}' -F '#{session_name}' | xargs -r -I{} tmux kill-session -t {}"

# 1. create branch $1, 2. create worktree for that branch, 3. switch to the worktree
alias add_worktree='f(){ b="$1"; p=$(basename "$PWD"); c=${b//@/}; d="../${p}-worktrees/$c"; git show-ref --verify --quiet refs/heads/"$b" || git branch "$b" main; git worktree add "$d" "$b"; cd "$d"; }; f'

# basically remove file changes from branch
alias resmain='git restore --source=origin/main --staged --worktree'

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# bun completions
[ -s "/Users/ignacylatka/.bun/_bun" ] && source "/Users/ignacylatka/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH=/Users/ignacylatka/.opencode/bin:$PATH

# maestro
export PATH=$PATH:$HOME/.maestro/bin

export NVM_DIR="$HOME/.nvm"

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

export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
