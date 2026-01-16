
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
