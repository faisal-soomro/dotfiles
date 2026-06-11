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

# Convenience wrapper over pi_from_here that warms the llama-server preset
# before the sandbox opens. Per Phase 3 sub-task 3h (shaheen-pi-agentic
# PAVE): the router takes 3-10s+ to swap heavy MoE primaries, so this
# fires a one-token request in the background while the sandbox spins up.
# By the time the user types their first prompt the model is hot.
#
# Defaults to the fleet primary (gemma4-26b-a4b — Gemma 4 26B-A4B QAT).
# Override per session: `pi_coding qwen3.6-35b-a3b` (for coding) or
# `pi_coding nemotron-30b-a3b` (reasoning).
#
# Warmup is silent and best-effort — if llama.home is down or the preset
# name is wrong, pi launches anyway and the first real prompt eats the
# load cost. No retries, no error handling beyond the 5s curl timeout.
pi_coding() {
    local model
    if [ "$#" -gt 0 ]; then
        model="$1"; shift
    else
        model="gemma4-26b-a4b"
    fi
    curl -s -m 5 -X POST "http://llama.home/v1/chat/completions" \
        -H 'Content-Type: application/json' \
        -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"warmup\"}],\"max_tokens\":1}" \
        >/dev/null 2>&1 &
    pi_from_here --provider llama-shaheen --model "$model" "$@"
}
