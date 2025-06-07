# Custom functions

# Create directory and enter it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Change to repository directory using ghq and fzf
repo() {
    local dir
    dir=$(ghq list | fzf --preview "bat --color=always --style=numbers --line-range=:500 $(ghq root)/{}/README.md 2>/dev/null || ls -la $(ghq root)/{}")
    if [[ -n "$dir" ]]; then
        cd "$(ghq root)/$dir"
    fi
}

# Find and open file in editor
vf() {
    local file
    file=$(fd --type f --hidden --follow --exclude .git | fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}')
    [[ -n "$file" ]] && ${EDITOR:-nvim} "$file"
}

# Extract archives
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Docker container shell
dsh() {
    docker exec -it "$1" /bin/bash || docker exec -it "$1" /bin/sh
}

# Git branch fuzzy finder
unalias gb 2>/dev/null || true
gb() {
    local branches branch
    branches=$(git branch --all | grep -v HEAD) &&
    branch=$(echo "$branches" | fzf -d $((2 + $(wc -l <<< "$branches"))) +m) &&
    git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

# Kill process using fzf
fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
    if [ "x$pid" != "x" ]; then
        echo "$pid" | xargs kill -${1:-9}
    fi
}

# Quick backup
backup() {
    cp -r "$1" "$1.backup.$(date +%Y%m%d%H%M%S)"
}

# Show PATH entries, one per line
path() {
    echo $PATH | tr ':' '\n'
}

# Weather
weather() {
    curl -s "wttr.in/${1:-}"
}

# Create a temporary directory and enter it
tmpd() {
    local dir
    if [ $# -eq 0 ]; then
        dir=$(mktemp -d)
    else
        dir=$(mktemp -d -t "${1}.XXXXXXXXXX")
    fi
    cd "$dir" || exit
}

# Show disk usage for current directory
usage() {
    du -sh * | sort -hr
}