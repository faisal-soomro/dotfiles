# Sandbox research

Goal, options compared, and decisions taken. Pure research — no state, no timeline. For current state and the deferred queue, see [`PLAN.md`](PLAN.md).

## Goal

Stop Claude Code (and any other AI coding harness) from polluting the host OS with native `pip install`, `npm install -g`, `apt`, etc. We want a sandboxed environment where:

- Tool installs and runtimes stay off the host
- Workflow stays interactive (terminal + VS Code) — not just one-shot agent runs
- Auth/login persists across sessions (don't re-login every time)
- Containers persist until explicitly thrown away (no auto-`--rm`)
- Repo edits still appear on host normally (bind-mounted)
- Approach is portable across editors / agent harnesses

### Scope clarification — what we want isolated vs shared

**Isolated (container only):**
- Anything the harness *installs at runtime* — pip packages, npm globals, apt packages, language runtimes, system libraries, build tools

**Shared from host (read-write bind-mount of `~/.claude/`):**
- The harness's *user configuration*: `CLAUDE.md`, `settings.json`, `skills/`, `hooks/`, `plugins/`, MCP server config — all the stuff the user has authored or set up. This is not a "runtime install"; it's part of the harness as the user has configured it.
- Session state (`projects/`, history) — pragmatically easier to share than isolate, and means `/insights` on host can see container sessions for free.

**Auth:**
- Both `~/.claude.json` (auth/credentials, at home root) and `~/.claude/` (config dir) are bind-mounted from host into the container's `$HOME`. Same files the host Claude uses — no redirect via `CLAUDE_CONFIG_DIR`, no separate copy.
- Mirrors the convention of the user's existing `gcloud_from_here` / `terraform_from_here` aliases: credentials live on host, container reads/writes them directly.
- Trade-off accepted: a session inside the container shares auth state with the host. Acceptable per the threat model (we're not defending against a rogue Claude, only stopping `pip`/`npm`/`apt` from polluting host).

This means a tool install inside the container (`pip install foo`) lands in the container's writable layer and disappears when the container exits. But everything the user has configured — skills, hooks, CLAUDE.md — is just there, inherited from host.

### File ownership — the load-bearing constraint

Claude *writes constantly* into the cwd (new files, build artefacts, `node_modules`, git index changes). If the container runs as root (UID 0) and the host user is UID 501, every file Claude creates lands on the host owned by `root:root` — needs `sudo chown` to edit or delete outside the container. This is the dominant pain point that doesn't bite `gcloud_from_here`-style aliases (which rarely write into cwd).

Three shapes considered:

| # | Approach | Ownership of new files on host | Cost |
|---|---|---|---|
| 1 | Run as host UID/GID (`docker run -u $(id -u):$(id -g)`) | Host user ✓ | No runtime `apt install` (acceptable — bake deps at build time); image must be built so any UID can use it |
| 2 | Run as root, `chown -R` on exit | Host user (eventually) | Fragile, breaks if container is killed; doesn't fix in-session |
| 3 | Run as root, accept root-owned files | root:root ✗ | `sudo` every time you touch a Claude-created file from the host |

**Decision: option 1.** All container-created files must land as the host user. That's the user's hard requirement.

Implications for the image:
- No baked-in user account with a fixed UID. Create a world-writable HOME (`chmod 777`) at the host HOME path (passed in via `--build-arg HOST_HOME="$HOME"`) so any runtime UID can use it, and so the host-absolute `installPath` field in `~/.claude/plugins/installed_plugins.json` resolves identically inside the container. (Wiki paths live under `/Users/Shared/wikis/`, mounted same-path — no HOST_HOME dependency. `/opt` was avoided because OrbStack injects its own dirs there and silently blanks bind-mount contents.)
- Install `claude` globally (e.g. into `/usr/local` via `npm i -g`) so it's on PATH regardless of runtime UID.
- Anything Claude wants to `npm i -g` or `pip install` at runtime needs a user-writable prefix — point npm/pip prefixes at the (writable) HOME.
- Known gotcha: `getpwuid(501)` inside the container returns "unknown user" because no matching `/etc/passwd` entry. Most tools tolerate it; `git` and `ssh` sometimes complain. If it bites, add a startup shim that appends a passwd entry; don't pre-empt it.

**Appendix (2026-05-24): symlink-resolution mount removed.** The alias previously also bind-mounted `$HOME/dev_workspace:ro` so that absolute-path symlinks inside `~/.claude/` (which then pointed into `~/dev_workspace/claude-settings/`) could resolve inside the container. After the home-as-repo migration (`~/.claude/` is now itself a git working tree with real files, no symlinks), that mount is no longer needed and has been removed. See `~/.claude/home-as-repo/RESEARCH.md` for the migration rationale.

### SSH credentials inside the sandbox

A host-installed SessionStart hook (`wiki-start-hook.sh`) runs `git pull` on session start. Inside the container this immediately fails because (a) `ssh` isn't installed and (b) no SSH credentials are reachable. This isn't a hypothetical — it surfaced the first time we ran the alias in a real repo, so it gets handled in Stage 1, not deferred.

Options considered:

| # | Approach | Trade-off |
|---|---|---|
| 1 | Install `openssh-client` in image + bind-mount `~/.ssh:ro` | Simple. Private keys are visible read-only to anything running in the container |
| 2 | Install `openssh-client` + forward `SSH_AUTH_SOCK` from host | More secure (keys stay in agent). Fiddly on macOS — host agent socket isn't a Linux socket; needs `host.docker.internal` workaround or a relay container |
| 3 | Make hooks tolerate missing `ssh` (silent skip) | No image change. Loses pull-on-start inside the sandbox |

**Decision: option 1** for v1. Matches the `gcloud_from_here` / `terraform_from_here` philosophy of trusting host credentials — same model as bind-mounting `~/.claude.json`. Container is single-tenant, ephemeral, and the threat model is install isolation, not credential confinement. If we later run untrusted agents (e.g. AFK Ralph), option 2 becomes worth the complexity.

### Deviation from published patterns

Most public guidance assumes the container is **self-contained** (team-shareable, security-hardened, no host config). We deviate because our use case is **personal install isolation**, not team distribution. Specifically:

| Pattern | What they recommend | Why we don't follow it |
|---|---|---|
| Anthropic devcontainer docs | Use a named volume per repo; explicitly warns against mounting host secrets | We want skills/hooks/plugins available everywhere, not duplicated per repo |
| Trail of Bits' `devc` | Isolated; sync back via `docker cp` | Adds complexity (label discovery, sync script) we don't need when host config is already in scope |
| Matt Pocock's workshop | `.claude/skills/` checked into the repo | His pattern is for workshop reproducibility, not personal daily use |
| Sandcastle | Default mounts only the repo worktree | It's for autonomous one-shot runs, not interactive sessions |

Our threat model: keep installs off host. We're *not* defending against a rogue Claude session that would deliberately corrupt host config. So sharing `~/.claude/` read-write is acceptable.

## Options surveyed

### 1. Anthropic dev containers (official)
- Docs: <https://code.claude.com/docs/en/devcontainer>
- Pattern: drop `.devcontainer/devcontainer.json` per repo
- Pros: official, open spec (containers.dev), works in VS Code / Cursor / JetBrains / Codespaces / `devcontainer` CLI, portable
- Cons: per-repo file, no built-in lifecycle CLI, no insights-sync

### 2. Docker Sandboxes (`sbx run claude`)
- Docs: <https://docs.docker.com/ai/sandboxes/agents/claude-code/>
- Pattern: `sbx run claude ~/path` — ephemeral microVM
- Matt Pocock praised the DX
- Pros: zero per-repo setup, strong isolation (microVM), interactive or one-shot
- Cons: Docker-specific UX (not portable to other harnesses), ephemeral by default, doesn't inherit `~/.claude`

### 3. mattpocock/sandcastle
- Repo: <https://github.com/mattpocock/sandcastle>
- TS library for **programmatic** sandboxed agent orchestration (Docker / Podman / Vercel microVMs)
- Not interactive — designed for autonomous agent runs from TS code
- Useful later for `/loop`-style autonomous experiments; not for daily work

### 4. Trail of Bits — claude-code-devcontainer
- Repo: <https://github.com/trailofbits/claude-code-devcontainer>
- Wraps Anthropic's devcontainer pattern with a `devc` CLI
- Three real wins over rolling our own:
  1. CLI lifecycle (`up`, `rebuild`, `shell`, `destroy`, `sync`, `cp`, `mount`, `upgrade`)
  2. Hardened defaults (iptables egress restriction, SSH agent forwarding, no host key mounts)
  3. **Session sync** — `devc sync` copies in-container `~/.claude/projects/` to host so `/insights` can see sandboxed sessions
- Cons: third-party, more deps, more opinionated than we need for v1

## Decision

**Roll our own minimal sandbox**, modelled on Trail of Bits' approach but stripped down. Build only what we've actually missed; layer additions on top.

Why ours, not theirs:
- We want full control of the surface area; Trail of Bits' script is ~700 lines of bash
- Their hardening (iptables egress) is not required for our threat model right now — we're keeping host installs clean, not defending against malicious code
- We want this to live alongside our other shell tooling in the `dotfiles` repo, next to existing `gcloud_from_here` / `terraform_from_here` aliases (was originally in `claude-settings/sandbox/`; moved when claude-settings became `~/.claude/` itself)
- The genuinely useful parts (the sync mechanism, the container labelling convention) are ~30 lines we can borrow when we need them

Why not Anthropic's devcontainers as the primary surface:
- They're great for portability (covered by Option 1), but they don't give us a one-line "run claude sandboxed in *this* dir" terminal experience
- They also can coexist with a terminal-first approach as a thin JSON layer on top, so we don't have to pick one — we'll add a `.devcontainer/devcontainer.json` template that targets the same image and named volume

Why not `sbx` (Docker Sandboxes):
- Ephemeral by default; doesn't inherit `~/.claude`; UX is Docker-specific. Useful as inspiration for one-shot agent runs, not for daily interactive work.

Why not `sandcastle`:
- Programmatic-only; not interactive. Reserve for future autonomous-run experiments.

The form factor of our sandbox is **deferred until used in anger**. Initial guess (alias-first, with devcontainer template alongside) is in `PLAN.md`. The CLI-wrapper version shipped in v1 was over-engineered; tagged as `experimental` and being rebuilt smaller.

## Sources

- [Anthropic — Development containers](https://code.claude.com/docs/en/devcontainer)
- [trailofbits/claude-code-devcontainer](https://github.com/trailofbits/claude-code-devcontainer) — especially `install.sh` for the `sync` mechanism
- [mattpocock/sandcastle](https://github.com/mattpocock/sandcastle) — programmatic sandboxing, future autonomous-runs option
- [Docker Sandboxes blog](https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/)
- [Mitja Martini — Claude Code in Devcontainers](https://mitjamartini.com/posts/claude-code-in-devcontainer/)
- [Sandboxing Claude Code on macOS — Infralovers](https://www.infralovers.com/blog/2026-02-15-sandboxing-claude-code-macos/)
