
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
alias cursor="/Applications/Cursor.app/Contents/MacOS/cursor"

# Created by `pipx` on 2024-04-01 10:13:01
# Added ~/dev/bin on Jan 15, 2026
export PATH="$HOME/dev/bin:$PATH:/Users/tanmaygupta/.local/bin"

# Python Homebrew
export PATH="/opt/homebrew/opt/python@3.10/libexec/bin:$PATH"
alias python=python3
alias pip=pip3

. "$HOME/.local/bin/env"
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"

# Adding starship
eval "$(starship init zsh)"

# Part of removing omzsh was making terminal simple.
# Adding my own history and auto complete commands now.
# History
export HISTSIZE=1000000
export SAVEHIST=1000000
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# Navigation
setopt autocd

# Completion
autoload -Uz compinit
compinit

# Zsh autosuggestions (ghost text, accept with right arrow)
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^[[C' autosuggest-accept

# Word navigation with Ctrl+Arrow keys
bindkey '^[[1;5C' forward-word   # Ctrl+Right
bindkey '^[[1;5D' backward-word  # Ctrl+Left

