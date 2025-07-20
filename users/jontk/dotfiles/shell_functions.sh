#!/usr/bin/env bash
# Custom shell functions
# This file is managed by Home Manager

# Create directory and cd into it
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
  if [ -f "$1" ]; then
    case $1 in
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
      *)           echo "'$1' cannot be extracted" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Find and replace in files
findreplace() {
  if [ $# -lt 3 ]; then
    echo "Usage: findreplace <find_pattern> <replace_pattern> <file_pattern>"
    return 1
  fi
  find . -type f -name "$3" -exec sed -i '' "s/$1/$2/g" {} +
}

# Git functions
git_current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null
}

git_main_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
}

# Quick git commit with message
# Unalias gcm if it exists to avoid conflicts
#unalias gcm 2>/dev/null || true
#gcm() {
#  git commit -m "$*"
#}

# Git pull and rebase current branch
gpr() {
  git pull --rebase origin "$(git_current_branch)"
}

# Docker functions
docker_clean() {
  docker system prune -af --volumes
}

docker_stop_all() {
  docker stop $(docker ps -aq)
}

docker_remove_all() {
  docker rm $(docker ps -aq)
}

# Nix functions
nix_clean() {
  nix-collect-garbage -d
  nix-store --optimise
}

nix_search() {
  nix search nixpkgs "$@"
}

# System information
# Commented out due to conflict with sysinfo alias
# sysinfo() {
#   echo "Hostname: $(hostname)"
#   echo "OS: $(uname -s) $(uname -r)"
#   echo "Uptime: $(uptime)"
#   echo "Memory: $(free -h 2>/dev/null || vm_stat | grep 'Pages free')"
#   echo "Disk: $(df -h / | tail -1)"
# }

# Weather (requires curl)
weather() {
  local location="${1:-}"
  curl -s "wttr.in/${location}?format=3"
}

# Quick backup
backup() {
  if [ $# -eq 0 ]; then
    echo "Usage: backup <file_or_directory>"
    return 1
  fi
  cp -r "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
}

# Port usage
port() {
  if [ $# -eq 0 ]; then
    echo "Usage: port <port_number>"
    return 1
  fi
  lsof -i ":$1" 2>/dev/null || echo "Port $1 is not in use"
}

# Quick HTTP server
# Commented out due to conflict with serve alias
# serve() {
#   local port="${1:-8000}"
#   python3 -m http.server "$port"
# }

# Colorful man pages
man() {
  env \
    LESS_TERMCAP_mb=$'\e[1;31m' \
    LESS_TERMCAP_md=$'\e[1;31m' \
    LESS_TERMCAP_me=$'\e[0m' \
    LESS_TERMCAP_se=$'\e[0m' \
    LESS_TERMCAP_so=$'\e[1;44;33m' \
    LESS_TERMCAP_ue=$'\e[0m' \
    LESS_TERMCAP_us=$'\e[1;32m' \
    man "$@"
}

# FZF powered functions (if fzf is available)
if command -v fzf &> /dev/null; then
  # Kill process
  fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
    if [ "x$pid" != "x" ]; then
      echo "$pid" | xargs kill -${1:-9}
    fi
  }

  # Checkout git branch
  fco() {
    local branches branch
    branches=$(git --no-pager branch -vv) &&
    branch=$(echo "$branches" | fzf +m) &&
    git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
  }

  # Search history
  fh() {
    print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
  }
fi
