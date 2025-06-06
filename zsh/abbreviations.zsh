# Abbreviations using zsh-abbr
# These expand when you press space or enter

# Navigation
abbr ".." "cd .."
abbr "..." "cd ../.."
abbr "...." "cd ../../.."
abbr "....." "cd ../../../.."

# Listing (using eza)
abbr "ls" "eza"
abbr "l" "eza -l"
abbr "la" "eza -la"
abbr "ll" "eza -lag"
abbr "lt" "eza --tree"
abbr "tree" "eza --tree"

# Git abbreviations
abbr "g" "git"
abbr "ga" "git add"
abbr "gaa" "git add --all"
abbr "gap" "git add --patch"
abbr "gc" "git commit"
abbr "gcm" "git commit -m"
abbr "gca" "git commit --amend"
abbr "gcan" "git commit --amend --no-edit"
abbr "gco" "git checkout"
abbr "gcob" "git checkout -b"
abbr "gd" "git diff"
abbr "gdc" "git diff --cached"
abbr "gds" "git diff --staged"
abbr "gf" "git fetch"
abbr "gl" "git log"
abbr "glg" "git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
abbr "gll" "git log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]' --decorate --numstat"
abbr "gpl" "git pull"
abbr "gps" "git push"
abbr "gpsu" "git push -u origin HEAD"
abbr "gs" "git status"
abbr "gst" "git status"
abbr "gss" "git stash save"
abbr "gsl" "git stash list"
abbr "gsp" "git stash pop"
abbr "gsa" "git stash apply"
abbr "gbr" "git branch"
abbr "grs" "git reset"
abbr "grsh" "git reset --hard"
abbr "grss" "git reset --soft"

# Lazygit abbreviations
abbr "lg" "lazygit"
abbr "lgs" "lazygit status"
abbr "lgb" "lazygit log"

# Docker abbreviations
abbr "d" "docker"
abbr "dc" "docker compose"
abbr "dps" "docker ps"
abbr "dpsa" "docker ps -a"
abbr "di" "docker images"
abbr "dr" "docker run"
abbr "drit" "docker run -it"
abbr "drm" "docker rm"
abbr "drmi" "docker rmi"
abbr "dl" "docker logs"
abbr "de" "docker exec"
abbr "deit" "docker exec -it"

# Editor abbreviations
abbr "v" "nvim"
abbr "vi" "nvim"
abbr "vim" "nvim"

# System abbreviations
abbr "reload" "exec \$SHELL"
abbr "path" "echo -e \${PATH//:/\\\\n}"
abbr "h" "history"
abbr "j" "jobs -l"
abbr "c" "clear"

# Safety nets with confirmation
abbr "rm" "rm -i"
abbr "cp" "cp -i"
abbr "mv" "mv -i"

# Create parent directories on demand
abbr "mkdir" "mkdir -pv"

# Human-readable sizes
abbr "df" "df -h"
abbr "du" "du -h"

# Process management
abbr "psg" "ps aux | grep -v grep | grep -i -e VSZ -e"
abbr "psmem" "ps auxf | sort -nr -k 4 | head -10"
abbr "pscpu" "ps auxf | sort -nr -k 3 | head -10"

# Network
abbr "ports" "netstat -tulanp"

# Kubernetes
abbr "k" "kubectl"
abbr "kg" "kubectl get"
abbr "kd" "kubectl describe"
abbr "ka" "kubectl apply"
abbr "kdel" "kubectl delete"
abbr "kl" "kubectl logs"
abbr "ke" "kubectl exec"
abbr "kp" "kubectl port-forward"

# Terraform
abbr "tf" "terraform"
abbr "tfi" "terraform init"
abbr "tfp" "terraform plan"
abbr "tfa" "terraform apply"
abbr "tfd" "terraform destroy"
abbr "tfv" "terraform validate"
abbr "tff" "terraform fmt"

# Tmux
abbr "tm" "tmux"
abbr "tma" "tmux attach"
abbr "tmn" "tmux new-session"
abbr "tml" "tmux list-sessions"

# Cargo (Rust)
abbr "cb" "cargo build"
abbr "cr" "cargo run"
abbr "ct" "cargo test"
abbr "cc" "cargo check"
abbr "cf" "cargo fmt"
abbr "ccl" "cargo clippy"

# npm/yarn
abbr "ni" "npm install"
abbr "nr" "npm run"
abbr "ns" "npm start"
abbr "nt" "npm test"
abbr "nb" "npm run build"
abbr "yi" "yarn install"
abbr "yr" "yarn run"
abbr "ys" "yarn start"
abbr "yt" "yarn test"
abbr "yb" "yarn build"