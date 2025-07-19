#!/usr/bin/env bash
# Shell environment setup
# This file is managed by Home Manager

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Create XDG directories if they don't exist
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

# Path configuration
typeset -U path  # Remove duplicates
path=(
  $HOME/.local/bin
  $HOME/.nix-profile/bin
  /nix/var/nix/profiles/default/bin
  /run/current-system/sw/bin
  $path
)

# Development paths
export GOPATH="${GOPATH:-$HOME/go}"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"

# Add development paths
path=(
  $GOPATH/bin
  $CARGO_HOME/bin
  $NPM_CONFIG_PREFIX/bin
  $path
)

# Editor configuration
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export SUDO_EDITOR="$EDITOR"

# Pager configuration
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R -F -X}"
export LESSHISTFILE="${LESSHISTFILE:-$XDG_STATE_HOME/less/history}"
export MANPAGER="${MANPAGER:-sh -c 'col -bx | bat -l man -p'}"
export MANWIDTH="${MANWIDTH:-80}"

# Language settings
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"

# History settings
export HISTFILE="${HISTFILE:-$XDG_STATE_HOME/bash/history}"
export HISTSIZE="${HISTSIZE:-100000}"
export HISTFILESIZE="${HISTFILESIZE:-100000}"
export SAVEHIST="${SAVEHIST:-$HISTSIZE}"

# FZF configuration
export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --follow --exclude .git}"
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-\
  --height 40% \
  --layout=reverse \
  --border \
  --inline-info \
  --preview 'bat --style=numbers --color=always --line-range :500 {}' \
  --preview-window=right:50%:hidden \
  --bind='ctrl-/:toggle-preview' \
  --bind='ctrl-u:preview-page-up' \
  --bind='ctrl-d:preview-page-down'}"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="${FZF_ALT_C_COMMAND:-fd --type d --hidden --follow --exclude .git}"

# Ripgrep configuration
export RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-$XDG_CONFIG_HOME/ripgrep/config}"

# GPG configuration
export GPG_TTY=$(tty)

# SSH configuration
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/ssh-agent.socket}"

# Docker configuration
export DOCKER_CONFIG="${DOCKER_CONFIG:-$XDG_CONFIG_HOME/docker}"
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"
export COMPOSE_DOCKER_CLI_BUILD="${COMPOSE_DOCKER_CLI_BUILD:-1}"

# Kubernetes configuration
export KUBECONFIG="${KUBECONFIG:-$XDG_CONFIG_HOME/kube/config}"
export KUBE_EDITOR="${KUBE_EDITOR:-$EDITOR}"

# AWS configuration
export AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$XDG_CONFIG_HOME/aws/config}"
export AWS_SHARED_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$XDG_CONFIG_HOME/aws/credentials}"

# Terraform configuration
export TF_CLI_CONFIG_FILE="${TF_CLI_CONFIG_FILE:-$XDG_CONFIG_HOME/terraform/terraformrc}"
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$XDG_CACHE_HOME/terraform/plugins}"

# Node.js configuration
export NODE_REPL_HISTORY="${NODE_REPL_HISTORY:-$XDG_STATE_HOME/node/repl_history}"
export NPM_CONFIG_USERCONFIG="${NPM_CONFIG_USERCONFIG:-$XDG_CONFIG_HOME/npm/npmrc}"
export NPM_CONFIG_CACHE="${NPM_CONFIG_CACHE:-$XDG_CACHE_HOME/npm}"

# Python configuration
export PYTHONSTARTUP="${PYTHONSTARTUP:-$XDG_CONFIG_HOME/python/startup.py}"
export PYTHON_HISTORY="${PYTHON_HISTORY:-$XDG_STATE_HOME/python/history}"
export PYTHONUSERBASE="${PYTHONUSERBASE:-$XDG_DATA_HOME/python}"
export WORKON_HOME="${WORKON_HOME:-$XDG_DATA_HOME/virtualenvs}"
export PIPENV_VENV_IN_PROJECT="${PIPENV_VENV_IN_PROJECT:-1}"

# Rust configuration
export RUSTUP_HOME="${RUSTUP_HOME:-$XDG_DATA_HOME/rustup}"
export CARGO_HOME="${CARGO_HOME:-$XDG_DATA_HOME/cargo}"

# Go configuration
export GOPATH="${GOPATH:-$XDG_DATA_HOME/go}"
export GOMODCACHE="${GOMODCACHE:-$XDG_CACHE_HOME/go/mod}"

# Ruby configuration
export GEM_HOME="${GEM_HOME:-$XDG_DATA_HOME/gem}"
export GEM_SPEC_CACHE="${GEM_SPEC_CACHE:-$XDG_CACHE_HOME/gem}"
export BUNDLE_USER_CONFIG="${BUNDLE_USER_CONFIG:-$XDG_CONFIG_HOME/bundle}"
export BUNDLE_USER_CACHE="${BUNDLE_USER_CACHE:-$XDG_CACHE_HOME/bundle}"
export BUNDLE_USER_PLUGIN="${BUNDLE_USER_PLUGIN:-$XDG_DATA_HOME/bundle}"

# Nix configuration
export NIX_CONF_DIR="${NIX_CONF_DIR:-$XDG_CONFIG_HOME/nix}"

# Platform specific
case "$(uname -s)" in
  Darwin)
    # macOS specific
    export HOMEBREW_NO_ANALYTICS=1
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_INSTALL_CLEANUP=1
    export HOMEBREW_BUNDLE_FILE="${HOMEBREW_BUNDLE_FILE:-$XDG_CONFIG_HOME/homebrew/Brewfile}"
    
    # Use GNU utilities if available
    if [[ -d /opt/homebrew/opt/coreutils/libexec/gnubin ]]; then
      path=(/opt/homebrew/opt/coreutils/libexec/gnubin $path)
    fi
    ;;
  Linux)
    # Linux specific
    export SYSTEMD_EDITOR="$EDITOR"
    ;;
esac

# Remove duplicates from PATH
typeset -U PATH path
export PATH