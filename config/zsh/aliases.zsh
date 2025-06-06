# Aliases

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Listing (using eza)
alias ls='eza'
alias l='eza -l'
alias la='eza -la'
alias ll='eza -lag'
alias lt='eza --tree'
alias tree='eza --tree'

# Git aliases
alias g='git'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gd='git diff'
alias gl='git log'
alias gp='git push'
alias gs='git status'
alias gst='git status'

# Docker aliases
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'

# Editor
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# System
alias reload='exec $SHELL'
alias path='echo -e ${PATH//:/\\n}'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Create parent directories on demand
alias mkdir='mkdir -pv'

# Colorize commands
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Human-readable sizes
alias df='df -h'
alias du='du -h'

# Process management
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias psmem='ps auxf | sort -nr -k 4 | head -10'
alias pscpu='ps auxf | sort -nr -k 3 | head -10'

# Network
alias ports='netstat -tulanp'

# Misc
alias h='history'
alias j='jobs -l'
alias c='clear'
alias k='kubectl'
alias tf='terraform'