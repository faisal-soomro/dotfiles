# Pi sandbox plan

Forward-looking plan for `dotfiles/pi_sandbox/`. Mirrors the `claude_sandbox/PLAN.md` shape — current state + acceptance criteria + deferred queue. For rationale see [`RESEARCH.md`](RESEARCH.md); for the canonical decision record see [phase-2-pi-sandbox.md](file:///Users/Shared/wikis/personal-wiki/sources/repos/local_ai_lab/shaheen-pi-agentic/phase-2-pi-sandbox.md) (D1–D8 from the 2026-06-10 grill).

Build only what we miss in practice. Don't add subcommands, flags, or features ahead of an actual need.

---

## Stage 1 — `pi_from_here` alias

Smallest viable pi sandbox. A Dockerfile and a single bash function. Symmetric to `claude_sandbox/` Stage 1.

### Build

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 24.04 + apt baseline + Node 20 + `@earendil-works/pi-coding-agent` (terminal command `pi`). HOST_HOME build arg, world-writable HOME, npm prefix into HOME. No `claude install` analog — defer per D5 last bullet. |
| `aliases.sh` | Defines `pi_from_here`: runs pi as host UID/GID against cwd, mount layout per D2 (single `~/.pi`, no `~/.claude`, `~/.config/octo-pi`, `~/.cache/octo-pi`, `~/.ssh:ro`, same-path cwd with `-w`, conditional wiki mounts). |

Build the image:

```bash
docker build --build-arg HOST_HOME="$HOME" \
  -t pi-sandbox \
  ~/dev_workspace/dotfiles/pi_sandbox/
```

`HOST_HOME` is baked into `ENV HOME` so absolute paths in `~/.pi/agent/settings.json` (e.g. the `skills` pointer) resolve identically inside and outside the container. Same rationale as claude-sandbox.

### Mounts

| Mount | Why |
|---|---|
| `$HOME/.pi → $HOME/.pi` | All pi host state (auth, settings, models, sessions, bin, **and the curated skills dir at `~/.pi/agent/skills/`** per D5) |
| `$HOME/.config/octo-pi → $HOME/.config/octo-pi` | Phase 1 D5 extension config (`wikiHome`, `.setup-hint-shown`) |
| `$HOME/.cache/octo-pi → $HOME/.cache/octo-pi` | Phase 1 D9 `turn-end-hook.log` survives `--rm` |
| `$HOME/.ssh → $HOME/.ssh:ro` | git auth (same as claude-sandbox) |
| `$(pwd) → $(pwd)` + `-w $(pwd)` | **Same-path mount** — see RESEARCH "Cwd mount" (Phase 1 D7 + dotfiles `0c3b098` fix) |
| `/Users/Shared/wikis/personal-wiki → same path` (conditional) | Octo extension `wikiHome` candidate, mounted only when host dir exists |
| `/Users/Shared/wikis/catenda-wiki → same path` (conditional) | Catenda wiki, mounted only when host dir exists |

**No `~/.claude` mount, no `~/.pi.json` mount.** See RESEARCH.

### Shell wiring (D7)

Two surgical edits to `dotfiles/shell/common.sh`:

1. Inside the `if command -v docker` branch, add (mirroring the existing `claude_sandbox` line):
   ```bash
   [ -f "$HOME/dev_workspace/dotfiles/pi_sandbox/aliases.sh" ] && source "$HOME/dev_workspace/dotfiles/pi_sandbox/aliases.sh"
   ```
2. Inside the `else` `_stub_missing docker ...` arg list, append `pi_from_here` so it warns on use when docker is absent.

### Host-side prereqs (one-time, per host)

These are **not sandbox bugs if missing** — they are user-side config the sandbox inherits via mounts.

| # | Prereq | Why |
|---|---|---|
| 1 | `~/.pi/agent/settings.json` `skills` pointer set to `["~/.pi/agent/skills"]` (or absolute `["$HOME/.pi/agent/skills"]` if tilde fails) | D5 — skill set is pi-owned, decoupled from `~/.claude/skills` |
| 2 | `~/.pi/agent/skills/` populated with curated subset | D5 — without it, `/list` is empty in pi |
| 3 | macbook only: `~/.pi/agent/settings.json` `packages` entry = `["git:github.com/faisal-soomro/octo-pi-extension"]` (not local path) | D5 — kills macbook-vs-shaheen divergence |
| 4 | `/octo-setup` run inside pi once, so `~/.config/octo-pi/config.json` has `wikiHome` set | Phase 1 D5 — without it, the extension SKIPs every `turn_end` |
| 5 | Pi already authenticated on host (`~/.pi/agent/auth.json` valid) | Mounted in; sandbox doesn't re-auth |

### Stage 1 acceptance criteria

Acceptance from a tracked repo NOT under any wiki root (per D8) — covers wiki mount + banner + breadcrumb in one launch. Suggested: `~/dev_workspace/trading-framework` (`~`-path tracked) or any other repo listed in `personal-wiki`'s `repos.yml`.

| # | Criterion | How to test | Status |
|---|---|---|---|
| 1 | Image builds clean | `docker build --build-arg HOST_HOME="$HOME" -t pi-sandbox ~/dev_workspace/dotfiles/pi_sandbox/` exits 0 | ⬜ |
| 2 | Alias resolves in a fresh shell | `type pi_from_here` returns the docker run line | ⬜ |
| 3 | Pi starts inside the container | `pi_from_here` from a tracked non-wiki repo opens the pi REPL | ⬜ |
| 4 | Container runs as host UID | Inside: `id -u` matches host `id -u` | ⬜ |
| 5 | Cwd visible inside container at its host path | `pwd` inside pi matches host `pwd` (no `/mnt/folder`) | ⬜ |
| 6 | Skills loaded from `~/.pi/agent/skills/` | `/list` inside pi shows the curated skill set, not claude's | ⬜ |
| 7 | Phase 1.5 session_start banner appears | Banner on pi launch shows pending-items summary from mounted `personal-wiki` (D13–D17) | ⬜ |
| 8 | Wiki actually mounted | Inside pi: `ls /Users/Shared/wikis/personal-wiki/wiki/.meta/pending.md` succeeds | ⬜ |
| 9 | Turn_end breadcrumb writes correctly | Commit something in the cwd repo, trigger a pi turn, confirm new entry appended to `wiki/.meta/pending.md` matching Phase 1 D8 schema (byte-identical to a claude-side entry) | ⬜ |
| 10 | Files created in container are host-owned | Inside pi: `touch <cwd>/ownership-test`. Outside: `ls -l ownership-test` shows host user, not root | ⬜ |
| 11 | Host stays clean — no npm leakage | Inside: `npm install -g cowsay`. Outside: `which cowsay` returns nothing on host | ⬜ |
| 12 | Auth persists across runs | Run twice; second run doesn't reprompt for pi auth | ⬜ |
| 13 | Turn_end hook log survives `--rm` | After exit, `~/.cache/octo-pi/turn-end-hook.log` on host contains entries from the session | ⬜ |

Stop and fix any failure before declaring Stage 1 done.

---

## Stage 2 — shaheen rollout

Once macbook acceptance passes, repeat on shaheen:

1. Pull dotfiles on shaheen (whatever the fleet bootstrap mechanism is — out of scope here).
2. Build the image: `docker build --build-arg HOST_HOME="$HOME" -t pi-sandbox ~/dev_workspace/dotfiles/pi_sandbox/`
3. Verify host prereqs: pi auth, settings.json shape, `~/.pi/agent/skills/` populated, `/octo-setup` run.
4. Re-run Stage 1 acceptance #1–#13 on shaheen. Closes the deferred T9/T10 from Phase 1's macbook-only acceptance (cross-host byte-diff of breadcrumbs).

Stage 2 also unblocks Phase 3 (engine stack) since the harness is now usable on the engine host.

---

## Discover-during-execute (residual unknowns from D8)

These are the only open questions left after the grill. None blocks scaffolding.

| # | Question | What we do if it bites |
|---|---|---|
| 1 | Does pi tilde-expand `~/.pi/agent/skills` in settings.json? | If not, switch host's settings.json to absolute `$HOME/.pi/agent/skills`. Same path inside container because of HOST_HOME bake. |
| 2 | Does pi need a build-time `pi install` analog to claude's? | If `pi /doctor` complains on first sandbox launch, add the step to the Dockerfile and rebuild. |
| 3 | Does `ctx.cwd` on Phase 1's `turn_end` populate correctly inside the sandbox under same-path cwd mount? | If not, debug Phase 1 extension's cwd resolution (Phase 1 D4 verify-at-execute note carried forward). |
| 4 | Sandbox pi version vs host pi version drift (sandbox built 2026-06-10 ships `0.74.2`; host `settings.json` shows `lastChangelogVersion: 0.78.1`) | Identify the source of host pi (different channel? manual install?) and either pin the npm install line to a tag or accept the drift if cross-host behavior matches. |

---

## Future stages (deferred — pull in only on actual need)

Order is roughly the order in which we expect a real need to surface. None of these is being built proactively.

1. **`pi_coding` warmup wrapper** — Phase 3 deliverable per D3. Thin wrapper over `pi_from_here` that fires a background curl at Phase 3's Caddy `llama.home:8080` route to warm the model before pi launches.
2. **`pi-settings` repo** — analog of `claude-settings`, version-controlled home for `~/.pi/agent/skills/` content. Trigger: skills churn frequently or fleet members need to share the same curated set. Currently a one-host, one-user concern.
3. **Shared `fleet-cli-base` image** — collapse duplicate apt+node layers across `claude_sandbox/` and `pi_sandbox/`. Trigger: a third CLI sandbox (gemini, codex, etc.).
4. **Collapse `aliases.sh` siblings** — merge `claude_sandbox/aliases.sh` and `pi_sandbox/aliases.sh` into a single `dotfiles/shell/sandboxes.sh`. Trigger: maintenance friction (user flagged this as borderline overkill during the grill — explicit revisit point).
5. **`pi install` build step** — see Discover #2 above. Only if `pi /doctor` actually complains.
6. **MCP / additional providers inside pi-sandbox** — Phase 4+ concern. Discover when needed.
7. **Image upgrade story** — `build --pull` or separate `upgrade` step to bump pi-coding-agent without full rebuild. Trigger: first slow rebuild.
8. **Wiki page extension** — add a "Running in a sandbox" section to `personal-wiki/wiki/ai/pi-coding-agent.md`. Trigger: Stage 1 acceptance passes and the sandbox sees real use.
