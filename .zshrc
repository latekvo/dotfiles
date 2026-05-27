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

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

export EDITOR='vim'

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ALIASES

# gh
alias cleanele="git clean -fdX"
alias nukele="git reset --hard && git clean -fd"

# git workflow
# 1. create branch $1, 2. create worktree for that branch, 3. switch to the worktree
alias add_worktree='f(){ b="$1"; p=$(basename "$PWD"); c=${b//@/}; d="../${p}-worktrees/$c"; git show-ref --verify --quiet refs/heads/"$b" || git branch "$b" main; git worktree add "$d" "$b"; cd "$d"; }; f'
# basically remove file changes from branch
alias resmain='git restore --source=origin/main --staged --worktree'

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

# python
alias pac="source .venv/bin/activate"

# package size diag
alias atlasprod="EXPO_UNSTABLE_ATLAS=true npx expo start --no-dev"
alias atlasdev="EXPO_UNSTABLE_ATLAS=true npx expo start --no-dev"

# other
# perma enable yolo mode
alias claude="claude --dangerously-skip-permissions"
# kill all processes using given port
alias killport='f(){ kill -9 $(lsof -t -i tcp:$1); }; f'

# MACOS ONLY
if [[ $(uname) == "Darwin" ]]; then
	# android studio
	export PATH="/Applications/Android Studio.app/Contents/MacOS:$PATH"		

	# ruby environment
	export PATH="$HOME/.rbenv/bin:$PATH"
	eval "$(rbenv init -)"
	
	# add brew to PATH - at beginning and end to ensure priority
	export PATH=/opt/homebrew/bin:$PATH
	export PATH=/opt/homebrew/bin/brew:$PATH
	export PATH=/opt/homebrew/opt:$PATH
	export PATH=/opt/homebrew/opt/ruby:$PATH
	export PATH=$PATH:/opt/homebrew/bin
	export PATH=$PATH:/opt/homebrew/bin/brew
	export PATH=$PATH:/opt/homebrew/opt
	export PATH=$PATH:/opt/homebrew/opt/ruby
	
	# ruby 
	export GEM_HOME=$HOME/.gem
	
	# add android SDK to path
	export ANDROID_HOME=/Users/ignacylatka/Library/Android/sdk

	# add JDK to PATH
	export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
	export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

	# perhaps bash compatibility - likely to be removed
	export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
fi

export PATH=$PATH:$HOME/.maestro/bin

# argent dev helper scripts
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
