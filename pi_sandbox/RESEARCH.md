# Pi sandbox research

Pi-specific rationale for `dotfiles/pi_sandbox/`. For the **canonical decision record** (D1–D8) with full option comparisons and reasoning, see [phase-2-pi-sandbox.md](file:///Users/Shared/wikis/personal-wiki/sources/repos/local_ai_lab/shaheen-pi-agentic/phase-2-pi-sandbox.md) in personal-wiki. This file captures the operator-facing summary and the points where pi diverges from `claude_sandbox/`.

For shared rationale (file ownership, SSH mount, HOST_HOME bake, the `/opt` OrbStack gotcha), see [`../claude_sandbox/RESEARCH.md`](../claude_sandbox/RESEARCH.md) — pi inherits all of it.

## Goal

Run [pi-coding-agent](https://github.com/earendil-works/pi-coding-agent) (`@earendil-works/pi-coding-agent` on npm, terminal command `pi`) in a sandboxed container against the host's local AI engine stack on shaheen, with the same host-install-pollution-prevention envelope as `claude_from_here`. Symmetric shape, independent image.

## What this sandbox shares with claude_sandbox

Inherited verbatim from `../claude_sandbox/`:

- Ubuntu 24.04 base, apt baseline (`curl ca-certificates git openssh-client jq ripgrep fd-find gh trash-cli`), Node 20 via NodeSource.
- `HOST_HOME` build-arg → `ENV HOME` bake. Same host-absolute path inside and outside container, so any tooling that stores absolute paths in config (pi's `~/.pi/agent/settings.json` is one) resolves correctly in both places.
- World-writable HOME + npm global prefix into HOME (`chmod 777 $HOST_HOME`, `npm config set prefix "$HOST_HOME/.npm-global"`) — same UID-agnostic-image trick so the alias can `-u "$(id -u):$(id -g)"` without a baked-in user.
- `~/.ssh:ro` mount for git auth.
- Same-path cwd mount (`-v "$(pwd):$(pwd)" -w "$(pwd)"`) — see "Cwd mount" below for why this matters more for pi than the doc text suggests.
- Conditional wiki mounts (`/Users/Shared/wikis/personal-wiki`, `/Users/Shared/wikis/catenda-wiki`) with `[ -d ... ]` guard + double-mount guard.

## What pi diverges on

### Separate image (D1)

Not a shared base layer. Two CLIs is not three; abstraction can come later when a third CLI lands. Disk cost of duplicate apt/node layers is irrelevant vs. the cognitive cost of an early base-image abstraction. Tag/version drift between claude and pi is desirable — one CLI's release should not rebuild the other.

### No `~/.claude` mount; skills are pi-owned (D5)

`claude_from_here` mounts `~/.claude` because that's where claude reads everything. Pi reads skills from `~/.claude/skills/` *by default* — but a generic mirror is wrong. Pi's skill set should be a curated subset specific to pi's usage (different model context budget, different agent loop).

Decision: skills live in host's `~/.pi/agent/skills/`, populated and curated by the user. The existing `~/.pi : $HOME/.pi` mount carries it for free — no `~/.claude` mount, no Dockerfile bake, no `pi-settings`-style repo yet.

Host-side config changes required (one-time, not sandbox-side):

- `~/.pi/agent/settings.json` `skills` pointer: `["~/.claude/skills"]` → `["~/.pi/agent/skills"]` (or absolute `["$HOME/.pi/agent/skills"]` if tilde-expansion in pi's settings reader turns out to be unreliable — verify at execute).
- Populate `~/.pi/agent/skills/` with the curated subset.
- macbook only: change `packages: ["../../dev_workspace/octo-pi-extension"]` to `packages: ["git:github.com/faisal-soomro/octo-pi-extension"]` to match shaheen's install (Phase 1 D11). Local-path extension dev moves to a different workflow.

Future direction: a versioned `pi-settings` repo (analogous to `claude-settings`) that owns `~/.pi/agent/skills/` content. Deferred — out of scope until skills churn or fleet members need the same set.

### No `~/.pi.json` mount

Verified on macbook 2026-06-10: pi has no top-level `~/.pi.json` analog to `~/.claude.json`. All pi state lives under `~/.pi/agent/` (auth.json, settings.json, models.json, sessions/, bin/). Single `~/.pi : $HOME/.pi` mount covers everything. The phase doc's draft `~/.pi.json` line assumed parity that pi doesn't have.

### Cwd mount is same-path (load-bearing, not cosmetic) (D2)

`claude_sandbox/aliases.sh` mounts cwd at its real host path (`-v "$cwd:$cwd" -w "$cwd"`), not at `/mnt/folder`. Pi gets the same treatment for the same reason — but the reason is even stronger for pi:

- Phase 1's `octo-pi-extension` `turn_end` hook compares `git rev-parse --show-toplevel` against absolute paths in `personal-wiki`'s `repos.yml`.
- A `/mnt/folder` remap would make every tracked repo silently SKIP — no breadcrumbs written, no error to point at.
- This bug bit `claude_from_here` first (fixed in dotfiles commit `0c3b098`); pi inherits the fix, not the bug.

If a future change wants to remap cwd to `/mnt/...` for any reason, it must also update both `octo-claude-plugin/hooks/stop.sh` and `octo-pi-extension`'s repo-toplevel matching logic — i.e. don't.

### Pi-specific extension cache mount (D2)

Phase 1 `octo-pi-extension` writes `turn_end` logs to `$HOME/.cache/octo-pi/turn-end-hook.log` (Phase 1 D9). Without an explicit mount, logs vanish with each `--rm`. The alias mounts `$HOME/.cache/octo-pi` (defensive `mkdir -p` first), same shape as `claude_sandbox/aliases.sh`'s `$HOME/.cache/octo` mount.

### Extension config mount

Phase 1 D5 stores `wikiHome` (and the `.setup-hint-shown` sentinel from D12) under `~/.config/octo-pi/`. Mounted same-path so `/octo-setup` run on host persists for sandbox sessions and vice versa.

## What's deferred (and why)

### `pi_coding` warmup wrapper → Phase 3 (D3)

The original phase doc included a `pi_coding` thin wrapper that fires a background warmup curl at `http://llama.home:8080` before launching pi. Two reasons to defer:

1. There is no llama.home Caddy route yet — that's a Phase 3 deliverable. Shipping a wrapper whose curl always times out is a phantom feature.
2. Phase 3 is the natural moment to land the wrapper — same change as the route it consumes.

Phase 2 ships only `pi_from_here`. `pi_coding` and any per-provider warmup variants get added in Phase 3.

### `pi install` analog to `claude install`

`claude_sandbox/Dockerfile` runs `claude install` at build time to write the standalone binary to `~/.local/bin/claude` (fixes a `/doctor` warning). Pi may or may not need an equivalent. Not added speculatively — discover at execute. If `pi /doctor` (or equivalent) yells inside the sandbox on first launch, add the step then.

### Shared `fleet-cli-base` image

If a third CLI sandbox lands (e.g. gemini, codex), the duplicate apt+node layers across `claude_sandbox/` and `pi_sandbox/` become worth consolidating into a `fleet-cli-base` image. Not before then — global "no premature abstraction" rule.

### Per-sandbox `aliases.sh` consolidation

`claude_sandbox/aliases.sh` and `pi_sandbox/aliases.sh` are siblings. If maintenance friction shows up (e.g. when wiring a third sandbox), collapse both into `dotfiles/shell/sandboxes.sh`. Not before then. (User flagged this as borderline overkill during the grill — explicit revisit point.)

## Sources

- [phase-2-pi-sandbox.md](file:///Users/Shared/wikis/personal-wiki/sources/repos/local_ai_lab/shaheen-pi-agentic/phase-2-pi-sandbox.md) — canonical D-block (D1–D8) from the 2026-06-10 grill
- [../claude_sandbox/RESEARCH.md](../claude_sandbox/RESEARCH.md) — shared sandbox rationale (file ownership, HOST_HOME bake, SSH mount, `/opt` gotcha)
- [phase-1-pi-extension.md](file:///Users/Shared/wikis/personal-wiki/sources/repos/local_ai_lab/shaheen-pi-agentic/phase-1-pi-extension.md) — Phase 1 D5/D9/D11 referenced above (extension config, log path, install command)
- [pi-coding-agent.md](file:///Users/Shared/wikis/personal-wiki/wiki/ai/pi-coding-agent.md) — pi-coding-agent overview (to be extended with a "Running in a sandbox" section)
