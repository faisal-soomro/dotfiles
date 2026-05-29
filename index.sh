# Entrypoint for the dotfiles shell config. Source this from your shell rc:
#   ~/.bashrc (Linux) / ~/.zshrc (macOS):
#     source "$HOME/dev_workspace/dotfiles/index.sh"
# Sources the shell-agnostic fragments; bash-only bits (prompt) load under bash.
# Not a script — no `set -euo pipefail` (this runs in interactive shells).

DOTFILES_DIR="$HOME/dev_workspace/dotfiles"

# _stub_missing <dependency> <name>...
# Define each <name> as a function that explains the missing dependency when
# run, instead of failing cryptically. Fragments call this when their required
# binary isn't on PATH — lazy: quiet at startup, warns only on use.
_stub_missing() {
    local dep=$1; shift
    local name
    for name in "$@"; do
        eval "${name}() { printf '%s: %s not installed\n' '${name}' '${dep}' >&2; return 127; }"
    done
}

# Fragments (each detects which shell it's running under as needed).
[ -f "$DOTFILES_DIR/shell/kube.sh" ]   && source "$DOTFILES_DIR/shell/kube.sh"
[ -f "$DOTFILES_DIR/shell/common.sh" ] && source "$DOTFILES_DIR/shell/common.sh"
[ -f "$DOTFILES_DIR/shell/prompt.sh" ] && source "$DOTFILES_DIR/shell/prompt.sh"
