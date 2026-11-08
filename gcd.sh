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
#     source ~/dev/dev-bin/gcd.sh
#
#   For bash (~/.bashrc or ~/.bash_profile):
#     source ~/dev/dev-bin/gcd.sh
#
# gopen.sh must sit in the same directory as this script.
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
  target="$("$_gcd_home/gopen.sh" "$1" --path)" && cd "$target"
}

# Resolved once at source time from this file's own location
# ($0 fallback covers zsh, where BASH_SOURCE is unset when sourcing)
_gcd_home="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
