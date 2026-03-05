#!/bin/bash

# gcd.sh
#
# Defines a shell function 'gcd' that changes directory to a project directory
# found by gopen.sh. This script should be sourced once in your shell rc file.
#
# SETUP INSTRUCTIONS:
# ===================
# Add the following line to your shell rc file:
#
#   For zsh (~/.zshrc):
#     source ~/.local/bin/gcd.sh
#
#   For bash (~/.bashrc or ~/.bash_profile):
#     source ~/.local/bin/gcd.sh
#
# After adding, reload your shell configuration:
#   source ~/.zshrc    # or source ~/.bashrc
#
# Or simply open a new terminal window.
#
# USAGE:
# ======
#   gcd <search_query>
#
# EXAMPLES:
# =========
#   gcd gui          # cd's into matching project directory (e.g., agent-coding-gui)
#   gcd myproject    # cd's into directory containing "myproject" in its name
#
# If multiple matches are found, you'll be prompted to choose one.

gcd() {
  local target
  target="$("${HOME}/.local/bin/gopen.sh" "$1" --path)" && cd "$target"
}
