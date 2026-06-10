# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Working conventions
- Exploratory questions ("what could we add?", "what's here?") get a direct answer
  only — no layout proposals, option tables, or rollout plans unless asked.
- No writes/edits without an explicit imperative ("add X", "do X", "commit").
  Spot something worth doing? Mention it in one line and wait.
- TL;DR first. Terse.

### Git
- Commit messages: `<area>: <lowercase imperative summary>`, scoped by the directory
  touched (e.g. `claude_sandbox: bake HOME into image`, `bash: add kubectl aliases`).
  Single line; no body unless the change needs rationale.
- Never commit unless explicitly asked. Never push, force-push, or run destructive
  git commands without an explicit instruction.
- **Author identity**: this is a personal repo. Commit as
  `faisal-soomro <h.faisalsoomro@gmail.com>`, not the machine's work identity.
  The machine's `git config` defaults to the work email — do **not** trust it; check
  `git log` for the repo's actual convention before committing. Override per-commit
  with `git -c user.name=… -c user.email=… commit …` (never modify `git config`).

## What this repo is

Personal dotfiles: shell config (`bashrc`, `bash_profile`) plus `claude_sandbox/` and `pi_sandbox/`,
Dockerized environments for Claude Code and pi-coding-agent respectively. There is no build system,
test suite, or application code — changes are shell scripts, Dockerfiles, and design docs.

## claude_sandbox

A sandbox that runs Claude Code inside a container so runtime installs (`pip`, `npm -g`, `apt`)
never touch the host, while the host repo and `~/.claude/` config are bind-mounted in.

Build the image (rebuild whenever the Dockerfile or `$HOME` changes):

```bash
docker build --build-arg HOST_HOME="$HOME" -t claude-sandbox ~/dev_workspace/dotfiles/claude_sandbox/
```

Run it (alias defined in `claude_sandbox/aliases.sh`, sourced by `bashrc`):

```bash
claude_from_here   # runs Claude in claude-sandbox against $(pwd)
```

### Load-bearing design constraints

These are decisions with non-obvious rationale (full detail in `claude_sandbox/RESEARCH.md`). Do not
undo them without understanding why they exist:

- **`HOST_HOME` is baked into `ENV HOME`.** The host-absolute `installPath` field inside
  `~/.claude/plugins/installed_plugins.json` must resolve to the *same* path inside and outside the
  container. No `/home/me` indirection, no `CLAUDE_CONFIG_DIR` redirect. This is why HOME is a build
  arg, not a fixed path. (Wiki paths live under `/Users/Shared/wikis/`, mounted same-path — they don't
  depend on `HOST_HOME`; the `claude_from_here` function only adds each wiki `-v` flag when the dir
  exists on host. `/opt` was tried first but OrbStack silently blanks bind-mount content under that
  path.)
- **Container runs as host UID/GID** (`-u $(id -u):$(id -g)`). Claude writes constantly into the cwd;
  running as root would leave host files owned by `root:root`. Consequence: the image has no baked-in
  user account, HOME is `chmod 777` so any UID can use it, and the npm global prefix points into HOME
  so runtime `npm i -g` works as a non-root UID. Don't add a fixed-UID user.
- **Auth and config are bind-mounted, not copied.** `~/.claude.json` (credentials) and `~/.claude/`
  (skills, hooks, settings, plugins) are mounted read-write from host. A container session shares auth
  state with the host — accepted per the threat model (the goal is stopping host pollution, not
  defending against a rogue Claude).
- **`~/.ssh` is mounted read-only** so the SessionStart `git pull` hook and git over SSH work inside
  the container. `getpwuid()` may warn about an unknown user (no `/etc/passwd` entry for the runtime
  UID); only add a passwd shim if it actually breaks something.

`RESEARCH.md` is pure rationale (options compared, decisions taken). `PLAN.md` tracks current state
and the deferred queue. Keep that split: rationale in RESEARCH, state/timeline in PLAN.

## pi_sandbox

Symmetric sibling of `claude_sandbox/` for [pi-coding-agent](https://github.com/earendil-works/pi-coding-agent)
(`@earendil-works/pi-coding-agent` on npm, terminal command `pi`). Same isolation envelope (host UID, HOST_HOME
bake, same-path cwd mount, conditional wikis), independent image, different mount surface.

Build the image:

```bash
docker build --build-arg HOST_HOME="$HOME" -t pi-sandbox ~/dev_workspace/dotfiles/pi_sandbox/
```

Run it (alias defined in `pi_sandbox/aliases.sh`):

```bash
pi_from_here   # runs pi in pi-sandbox against $(pwd)
```

### Load-bearing design constraints (pi-specific deltas)

Inherits everything from `claude_sandbox/` above. Pi-specific deltas worth flagging here (full
rationale in `pi_sandbox/RESEARCH.md` and personal-wiki Phase 2 D-block D1–D8):

- **No `~/.claude` mount.** Pi's skills are curated separately in host's `~/.pi/agent/skills/` and
  carried via the existing `~/.pi` mount. Don't add a `~/.claude` mount "for parity" — the decoupling
  is intentional (D5).
- **No `~/.pi.json` mount.** Pi has no top-level config file analog to `~/.claude.json`; all pi
  state lives under `~/.pi/agent/`.
- **Host-side prereqs** for the sandbox to be useful: `~/.pi/agent/settings.json` `skills` pointer at
  `~/.pi/agent/skills/`, that directory populated, and `/octo-setup` run once so the octo-pi-extension
  has its `wikiHome`. See `pi_sandbox/PLAN.md` "Host-side prereqs".
- **`pi_coding` warmup wrapper does NOT live here yet** — deferred to Phase 3 of the shaheen-pi-agentic
  PAVE (it consumes the Caddy `llama.home:8080` route built there). Don't pre-add it.

## Shell config

`index.sh` is the single entrypoint — your live shell rc (`~/.bashrc` / `~/.zshrc`) sources it, and
it sources the fragments. The repo is not auto-loaded; wiring is a one-line `source` per machine.

Loading chain:
- `index.sh` defines the `_stub_missing` helper, then sources `shell/kube.sh`,
  `shell/common.sh`, and `shell/prompt.sh`. No shell-specific branches here — each
  fragment self-detects via `$BASH_VERSION` / `$ZSH_VERSION`.
- `shell/common.sh` — `*_from_here` Docker aliases + `claude_from_here` (sources
  `claude_sandbox/aliases.sh`). All wrapped in a `command -v docker` check.
- `shell/kube.sh` — kubectl/kubectx aliases, wrapped in per-binary `command -v` checks.
- `shell/prompt.sh` — cross-shell prompt: `git_branch` + `PS1` (bash) / `PROMPT` (zsh).
  Non-printing escape markers differ per shell: `\001/\002` in bash, `%{ %}` in zsh
  (under `PROMPT_SUBST`). Replaces oh-my-zsh's prompt by design.

The repo deliberately ships no `bashrc`/`bash_profile`. Users add one `source` line
to their live `~/.bashrc` / `~/.zshrc` — see README §Wiring.

Conventions to follow:
- **Lazy stubs over silent skips.** When a fragment's binary is absent, call `_stub_missing <dep>
  <name>...` so the alias warns *on use* instead of failing cryptically. Don't print warnings at
  source time (noisy on every shell).
- **`*_from_here`** aliases run a tool in an ephemeral (`--rm`) container with host credentials
  bind-mounted and `$(pwd)` as the workdir. Follow that pattern for new ones.
- **No `set -euo pipefail`** in fragments — they are sourced into interactive shells, not run as
  scripts. End `index.sh` cleanly (no trailing short-circuit that leaks a non-zero `$?`).
