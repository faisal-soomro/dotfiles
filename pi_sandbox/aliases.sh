# Sourced by dotfiles/index.sh (via shell/common.sh) — see repo README.

# Run pi (pi-coding-agent) in a sandboxed container against the current
# directory. Mirrors claude_from_here shape — same isolation envelope,
# different CLI. See pi_sandbox/RESEARCH.md for the points where pi
# diverges from claude (no ~/.claude mount, pi-owned skills dir, etc.).
#
# HOME inside the container matches the host HOME (baked into the image
# via --build-arg HOST_HOME="$HOME"). That keeps absolute paths inside
# ~/.pi/agent/settings.json (e.g. the `skills` pointer at
# ~/.pi/agent/skills) resolving identically inside and outside the
# sandbox. Wiki paths under /Users/Shared are absolute and don't need
# the HOST_HOME bake — same-path mounts are sufficient.
#
# Mounts:
#   $HOME/.pi                               → same path  — pi state: auth, settings, models, sessions, bin, skills
#   $HOME/.config/octo-pi                   → same path  — octo-pi-extension config (wikiHome, setup sentinel)
#   $HOME/.cache/octo-pi                    → same path  — octo-pi-extension turn-end log (so it survives --rm)
#   $HOME/.ssh                              → same path:ro — SSH keys for git
#   $(pwd)                                  → same path  — the repo we're working on
#   /Users/Shared/wikis/personal-wiki       → same path  — octo extension wikiHome (only if dir exists)
#   /Users/Shared/wikis/catenda-wiki        → same path  — catenda wiki (only if dir exists)
#
# Why mount cwd at its real host path (not /mnt/folder): pi's
# octo-pi-extension turn_end hook compares `git rev-parse --show-toplevel`
# against absolute paths in repos.yml. A /mnt/folder remap makes every
# tracked repo SKIP silently. Same-path mount keeps git's toplevel
# identical inside and outside the sandbox. Same fix that landed for
# claude_from_here in dotfiles commit 0c3b098.
#
# Why NO ~/.claude mount: skills for pi are curated separately at
# ~/.pi/agent/skills/ (carried via the ~/.pi mount), not mirrored from
# ~/.claude/skills. See pi_sandbox/RESEARCH.md "No ~/.claude mount" and
# Phase 2 D5 in personal-wiki for the decision and host-side prereqs.
#
# Wiki mounts are conditional: docker silently creates an empty
# (root-owned) source dir if you bind-mount a missing path, so we guard
# each with `[ -d … ]`. Also guard against double-mounting when cwd is
# already under a wiki root.
#
# Container is ephemeral (--rm); everything that needs to persist lives on host.
pi_from_here() {
    local cwd; cwd="$(pwd)"
    mkdir -p "$HOME/.cache/octo-pi" 2>/dev/null || true
    local args=(
        --rm -it
        -u "$(id -u):$(id -g)"
        -v "$HOME/.pi:$HOME/.pi"
        -v "$HOME/.config/octo-pi:$HOME/.config/octo-pi"
        -v "$HOME/.cache/octo-pi:$HOME/.cache/octo-pi"
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
    docker run "${args[@]}" pi-sandbox pi "$@"
}
