# Shell aliases and shortcuts
# Using aliases for reliable functionality

# Navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Enhanced listing with eza
alias ls='eza'
alias l='eza -l'
alias la='eza -la'
alias ll='eza -lag'
alias lt='eza --tree'
alias tree='eza --tree'

# Git shortcuts
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gap='git add --patch'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gd='git diff'
alias gdc='git diff --cached'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git log'
alias glg="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gll="git log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]' --decorate --numstat"
alias gpl='git pull'
alias gps='git push'
alias gpsu='git push -u origin HEAD'
alias gs='git status'
alias gst='git status'
alias gss='git stash save'
alias gsl='git stash list'
alias gsp='git stash pop'
alias gsa='git stash apply'
alias gbr='git branch'
alias grs='git reset'
alias grsh='git reset --hard'
alias grss='git reset --soft'

# Lazygit shortcuts
alias lg='lazygit'
alias lgs='lazygit status'
alias lgb='lazygit log'

# Docker shortcuts
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dr='docker run'
alias drit='docker run -it'
alias drm='docker rm'
alias drmi='docker rmi'
alias dl='docker logs'
alias de='docker exec'
alias deit='docker exec -it'

# Editor shortcuts
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# System shortcuts
alias reload='exec $SHELL'
alias path='echo -e ${PATH//:/\\n}'
alias h='history'
alias j='jobs -l'
alias c='clear'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Enhanced commands
alias mkdir='mkdir -pv'
alias df='df -h'
alias du='du -h'

# Process management
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias psmem='ps auxf | sort -nr -k 4 | head -10'
alias pscpu='ps auxf | sort -nr -k 3 | head -10'

# Network
alias ports='netstat -tulanp'

# Kubernetes shortcuts
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias ka='kubectl apply'
alias kdel='kubectl delete'
alias kl='kubectl logs'
alias ke='kubectl exec'
alias kp='kubectl port-forward'

# Terraform shortcuts
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tff='terraform fmt'

# Tmux shortcuts
alias tm='tmux'
alias tma='tmux attach'
alias tmn='tmux new-session'
alias tml='tmux list-sessions'

# Cargo (Rust) shortcuts
alias cb='cargo build'
alias cr='cargo run'
alias ct='cargo test'
alias cc='cargo check'
alias cf='cargo fmt'
alias ccl='cargo clippy'

# npm/yarn shortcuts
alias ni='npm install'
alias nr='npm run'
alias ns='npm start'
alias nt='npm test'
alias nb='npm run build'
alias yi='yarn install'
alias yr='yarn run'
alias ys='yarn start'
alias yt='yarn test'
alias yb='yarn build'