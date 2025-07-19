#!/usr/bin/env bash
# Kitty shell integration
# This file is managed by Home Manager

# Only run if in Kitty
if [[ "$TERM" != "xterm-kitty" ]]; then
  return 0
fi

# Kitty shell integration
if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
  export KITTY_SHELL_INTEGRATION="enabled"
  
  # Source Kitty's shell integration if available
  if [[ -n "$BASH_VERSION" ]]; then
    if [[ -r "${KITTY_INSTALLATION_DIR}/shell-integration/bash/kitty.bash" ]]; then
      source "${KITTY_INSTALLATION_DIR}/shell-integration/bash/kitty.bash"
    fi
  elif [[ -n "$ZSH_VERSION" ]]; then
    if [[ -r "${KITTY_INSTALLATION_DIR}/shell-integration/zsh/kitty.zsh" ]]; then
      source "${KITTY_INSTALLATION_DIR}/shell-integration/zsh/kitty.zsh"
    fi
  fi
fi

# Kitty specific aliases
alias icat="kitty +kitten icat"
alias kdiff="kitty +kitten diff"
alias kclip="kitty +kitten clipboard"
alias kssh="kitty +kitten ssh"

# Functions for Kitty features
kitty_set_tab_title() {
  echo -en "\033]2;$1\007"
}

kitty_set_window_title() {
  echo -en "\033]0;$1\007"
}

# Create new window in same directory
kitty_new_window() {
  kitty @ launch --type=window --cwd=current
}

# Create new tab in same directory
kitty_new_tab() {
  kitty @ launch --type=tab --cwd=current
}

# Set tab color
kitty_tab_color() {
  local color="${1:-none}"
  kitty @ set-tab-color "$color"
}

# Remote file editing
kitty_remote_edit() {
  local file="$1"
  if [[ -n "$SSH_CONNECTION" ]]; then
    echo -en "\033]52;f;$(echo -n "$file" | base64)\007"
  else
    ${EDITOR:-vim} "$file"
  fi
}

# Aliases for common operations
alias kt="kitty_new_tab"
alias kw="kitty_new_window"
alias ktitle="kitty_set_tab_title"

# Enable Kitty's SSH helper
if command -v kitten &>/dev/null; then
  alias s="kitten ssh"
fi