# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

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

# other
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
