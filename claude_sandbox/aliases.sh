# Sourced by dotfiles/index.sh (via shell/common.sh) — see repo README.

# Run Claude in a sandboxed container against the current directory.
# Mirrors the convention of gcloud_from_here / terraform_from_here, with
# one addition: -u $(id -u):$(id -g) so any file Claude writes in the
# repo lands as the host user, not root. See RESEARCH.md "File ownership".
#
# HOME inside the container matches the host HOME (baked into the image
# via --build-arg HOST_HOME="$HOME"). That keeps host-absolute paths in
# ~/.claude/plugins/installed_plugins.json resolving identically inside
# and outside the sandbox. Wiki paths under /Users/Shared are absolute
# and don't need the HOST_HOME bake — same-path mounts are sufficient.
# (/opt was avoided because OrbStack injects its own dirs there and bind
# mounts of host /opt content come through empty.)
#
# Mounts:
#   $HOME/.claude.json                      → same path  — auth/credentials
#   $HOME/.claude                           → same path  — config: skills, hooks, settings, plugins
#   $HOME/.cache/octo                       → same path  — octo hook logs (so they survive --rm)
#   $HOME/.ssh                              → same path:ro — SSH keys for git
#   $(pwd)                                  → same path  — the repo we're working on
#   /Users/Shared/wikis/personal-wiki       → same path  — octo plugin wikiHome (only if dir exists)
#   /Users/Shared/wikis/catenda-wiki        → same path  — catenda plugin wikiHome (only if dir exists)
#
# Why mount cwd at its real host path (not /mnt/folder): the octo Stop hook
# matches `git rev-parse --show-toplevel` against absolute paths in repos.yml.
# A /mnt/folder remap makes every tracked repo SKIP silently. Same-path mount
# keeps git's toplevel identical inside and outside the sandbox.
# (Surfaced 2026-06-07 during shaheen-pi-agentic PAVE Phase 0.)
#
# Wiki mounts are conditional: docker silently creates an empty (root-owned)
# source dir if you bind-mount a missing path, so we guard each with `[ -d … ]`.
# Also guard against double-mounting when cwd is already under a wiki root.
#
# Container is ephemeral (--rm); everything that needs to persist lives on host.
claude_from_here() {
    local cwd; cwd="$(pwd)"
    mkdir -p "$HOME/.cache/octo" 2>/dev/null || true
    local args=(
        --rm -it
        -u "$(id -u):$(id -g)"
        -v "$HOME/.claude.json:$HOME/.claude.json"
        -v "$HOME/.claude:$HOME/.claude"
        -v "$HOME/.cache/octo:$HOME/.cache/octo"
        -v "$HOME/.ssh:$HOME/.ssh:ro"
        -v "$cwd:$cwd"
        -w "$cwd"
    )
    local wiki
    for wiki in /Users/Shared/wikis/personal-wiki /Users/Shared/wikis/catenda-wiki; do
        [ -d "$wiki" ] || continue
        case "$cwd" in "$wiki"|"$wiki"/*) continue ;; esac  # cwd mount already covers it
        args+=(-v "$wiki:$wiki")
    done
    docker run "${args[@]}" claude-sandbox claude
}
