#!/usr/bin/env bash
# Alacritty shell integration
# This file is managed by Home Manager

# Set terminal title
set_alacritty_title() {
  echo -ne "\033]0;${1}\007"
}

# Update title with current directory
update_alacritty_title() {
  set_alacritty_title "${USER}@${HOSTNAME}: ${PWD/#$HOME/~}"
}

# Set up prompt command for title updates
if [[ -n "$BASH_VERSION" ]]; then
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }update_alacritty_title"
elif [[ -n "$ZSH_VERSION" ]]; then
  precmd_functions+=(update_alacritty_title)
fi

# Alacritty-specific environment
export COLORTERM=truecolor

# Enable true color support in various tools
export MICRO_TRUECOLOR=1
export BAT_THEME="Dracula"

# Alacritty terminfo
if [[ ! -f /usr/share/terminfo/a/alacritty ]]; then
  export TERM=xterm-256color
else
  export TERM=alacritty
fi