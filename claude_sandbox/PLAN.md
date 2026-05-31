# Sandbox plan

Forward-looking plan for `dotfiles/claude_sandbox/` (previously `claude-settings/sandbox/` — moved here in the claude-settings home-as-repo migration). Two stages, each with explicit acceptance criteria before moving on. For the rationale behind these choices see [`RESEARCH.md`](RESEARCH.md).

Build only what we miss in practice. Don't add subcommands, flags, or features ahead of an actual need.

---

## Stage 1 — `claude_from_here` alias

Smallest viable sandbox. A Dockerfile and a single bash alias. No CLI wrapper.

### Build

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu base + node + `@anthropic-ai/claude-code` + `openssh-client` + `jq`. **No baked-in user.** Takes a `HOST_HOME` build arg, creates that path as a world-writable HOME, sets `ENV HOME=$HOST_HOME`, and points the npm global prefix there so runtime `npm i -g` has somewhere to land. |
| `aliases.sh` | Defines `claude_from_here`: runs Claude as the host UID/GID against the current directory, bind-mounting `~/.claude.json`, `~/.claude/`, `~/.ssh:ro`, and any `/Users/Shared/wikis/*` dirs that exist on the host. |

Build the image with:

```bash
docker build \
  --build-arg HOST_HOME="$HOME" \
  -t claude-sandbox \
  ~/dev_workspace/dotfiles/claude_sandbox/
```

`HOST_HOME` is baked in so the host-absolute `installPath` field inside `~/.claude/plugins/installed_plugins.json` (under `$HOME`) resolves identically inside and outside the container. Rebuild if you move to a machine with a different `$HOME`. Wiki paths under `/Users/Shared/wikis/` don't need the bake — they're same-path mounts. (`/opt` was tried first but OrbStack silently blanks bind-mount content under that path.)

The function shape (an alias can't conditionally include `-v` flags):

```bash
claude_from_here() {
    local args=(
        --rm -it
        -u "$(id -u):$(id -g)"
        -v "$HOME/.claude.json:$HOME/.claude.json"
        -v "$HOME/.claude:$HOME/.claude"
        -v "$HOME/.ssh:$HOME/.ssh:ro"
        -v "$(pwd):/mnt/folder"
        -w /mnt/folder
    )
    [ -d /Users/Shared/wikis/personal-wiki ] && args+=(-v /Users/Shared/wikis/personal-wiki:/Users/Shared/wikis/personal-wiki)
    [ -d /Users/Shared/wikis/catenda-wiki ]  && args+=(-v /Users/Shared/wikis/catenda-wiki:/Users/Shared/wikis/catenda-wiki)
    docker run "${args[@]}" claude-sandbox claude
}
```

Mounts, line by line:

| Mount | Why |
|---|---|
| `$HOME/.claude.json → $HOME/.claude.json` | Auth/credentials, mirrors `gcloud_from_here` convention |
| `$HOME/.claude → $HOME/.claude` | Config dir: skills, hooks, CLAUDE.md, settings, plugins |
| `/Users/Shared/wikis/personal-wiki → same path` (conditional) | `wikiHome` for the octo plugin — `SessionStart`/`Stop` hooks read/write `pending.md`, `repos.yml` under this dir. Mounted only when the dir exists on host. |
| `/Users/Shared/wikis/catenda-wiki → same path` (conditional) | `wikiHome` for the catenda plugin. Mounted only when the dir exists on host. |
| `$HOME/.ssh → $HOME/.ssh:ro` | SSH keys for `git pull` / `git push`. See RESEARCH.md "SSH credentials inside the sandbox" |
| `$(pwd) → /mnt/folder` | The repo we're working on |

Why `-u $(id -u):$(id -g)` and the host-matching HOME: see RESEARCH.md "File ownership" — all files Claude writes must land as the host user, not root.

### Step-by-step build order

Per the global teaching-walkthrough rule (one file, one step, verify after each):

1. Write `Dockerfile` → build the image → verify the image exists (`docker images | grep claude-sandbox`)
2. Write `aliases.sh` → source it in a fresh shell → verify the alias resolves (`type claude_from_here`)
3. Run the alias against a low-stakes dir (e.g. `~/dev_workspace/trading-journal`) → Claude starts → either already authed (because host `~/.claude.json` is mounted in) or log in once
4. Exit. Touch a file from inside the container, exit, `ls -l` on host → confirm host-user ownership, not root
5. Re-run the alias in the same dir → confirm no re-login (auth shared via bind-mounted `~/.claude.json`)

### Stage 1 acceptance criteria

Don't move to Stage 2 until all of these pass.

| # | Criterion | How to test | Status |
|---|---|---|---|
| 1 | Image builds clean | `docker build --build-arg HOST_HOME="$HOME" -t claude-sandbox ~/dev_workspace/dotfiles/claude_sandbox/` exits 0 | ✅ |
| 2 | Alias resolves in a fresh shell | `type claude_from_here` returns the docker run line | ✅ |
| 3 | Claude starts inside the container | `claude_from_here` opens the Claude CLI | ✅ |
| 4 | Container runs as host UID | Inside: `id -u` matches host `id -u` (e.g. 501) | ✅ |
| 5 | Repo files visible inside container | `ls /mnt/folder` shows the host directory contents | ✅ |
| 6 | Edits in container appear on host | Touch a file inside; it shows up on host via `ls` | ✅ |
| 7 | Host stays clean — no leakage from `pip` | Inside container: `pip install requests`. Outside: `which pip` either reports no host pip touched or a fresh `pip list` on host doesn't show `requests` | ✅ |
| 8 | Host stays clean — no leakage from `npm -g` | Inside container: `npm install -g cowsay`. Outside: `which cowsay` returns nothing on host | ✅ |
| 9 | Container is gone after exit | `docker ps -a --filter "ancestor=claude-sandbox"` returns no rows | ✅ |
| 10 | Files created in container are host-owned | Inside: `touch /mnt/folder/ownership-test`. Outside: `ls -l ownership-test` shows host user, not root | ✅ |
| 11 | Auth persists across runs | Run twice; second run skips login (because `~/.claude.json` is bind-mounted from host) | ✅ |

**Stage 1 DONE** (2026-05-24).

If any of #5-#11 fail we stop and fix before continuing.

---

## Stage 2 — team rollout

Stage 1 served a single developer. Stage 2 widens the audience to other Catenda developers, who pick one of two entry points depending on workflow:

| Track | Best for | Entry point |
|---|---|---|
| **A. Terminal alias** (`claude_from_here`) | CLI-first devs; lowest friction | `aliases.sh` from this repo |
| **B. Devcontainer** (per-repo `.devcontainer/devcontainer.json`) | IDE-first devs (VS Code, IntelliJ Ultimate, Cursor) | Reference shape below, copy-pasted into each project |

Both tracks converge on the same end state: Claude Code running in a container as the host UID, with auth in `~/.claude/`. Different ergonomics, same security envelope.

### Why two tracks

A single artifact can't serve both audiences cleanly:

| | Track A (alias) | Track B (devcontainer) |
|---|---|---|
| Granularity | Process per `cd && claude_from_here` invocation | Long-lived container per repo |
| IDE integration | None — terminal only | Extension panel, diff viewer, diagnostic sharing |
| Setup cost per dev | Clone dotfiles + build image once → use anywhere | Drop `.devcontainer/` into each repo |
| Image | Catenda-maintained (`claude-sandbox`, this dir) | Anthropic-maintained (Dev Container Feature) |
| Anthropic-blessed posture | ❌ deviates on `~/.ssh`, host-bind for `~/.claude` | ✅ matches Anthropic's reference |
| Auth persistence | Host `~/.claude.json` bind-mount | Named volume per project |

Track A is faster onboarding and cheaper to support. Track B is IDE-native and easier for new devs to discover via the "Reopen in Container" prompt. We ship both.

### Track A — team alias rollout

The Stage 1 alias is mostly portable already. Three things differ from "personal use":

| Item | Action for team |
|---|---|
| Wiki mounts (`/Users/Shared/wikis/personal-wiki`, `/Users/Shared/wikis/catenda-wiki`) | Already conditional via `[ -d … ]` guards in the Stage 1 function. Hosts without those dirs simply get no mount — no per-dev edit needed. |
| `~/.ssh:ro` mount | Keep, but document it explicitly. Anthropic warns against it; each dev should accept the trade-off knowingly. Provide a commented-out variant for opt-out. |
| `HOST_HOME` default | Make `docker build` fail loudly when `--build-arg HOST_HOME` is missing — no silent fall-back to `/home/me`. |

Rollout instructions (what each dev does):

```bash
# 1. Clone the dotfiles repo
git clone <catenda-dotfiles-url> ~/dev_workspace/dotfiles

# 2. Build the sandbox image (one-time, ~3min first run)
docker build --build-arg HOST_HOME="$HOME" \
  -t claude-sandbox ~/dev_workspace/dotfiles/claude_sandbox/

# 3. Source the dotfiles entrypoint from your shell rc (~/.zshrc or ~/.bashrc)
echo 'source "$HOME/dev_workspace/dotfiles/index.sh"' >> ~/.zshrc

# 4. Reload the shell
exec zsh -l

# 5. Use it
cd <any repo>
claude_from_here
```

First run prompts for sign-in (browser). Auth persists on host in `~/.claude.json`.

### Track B — devcontainer reference

Per-project. Each Catenda project that wants IDE integration drops the following `devcontainer.json` into its repo root under `.devcontainer/`. Uses Anthropic's official Dev Container Feature on a Microsoft-maintained base image — no custom Dockerfile to maintain.

```json
{
  "name": "claude-code",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/anthropics/devcontainer-features/claude-code:1": {}
  },
  "mounts": [
    "source=claude-code-config-${devcontainerId},target=/home/vscode/.claude,type=volume"
  ],
  "customizations": {
    "vscode": { "extensions": ["anthropic.claude-code"] }
  }
}
```

Why this shape:

- **Microsoft base image** ships a `vscode` user, sudo, git, common tools — solves the user-identity problem without us writing a Dockerfile.
- **Node feature** is required: the Claude Code feature shells out to `npm` to install the CLI, and `mcr.microsoft.com/devcontainers/base:ubuntu` doesn't bundle Node.
- **Named volume** at `~/.claude` persists auth/settings across rebuilds. Per-project isolation via `${devcontainerId}` — change to a fixed name (e.g. `claude-code-config`) to share auth across projects.
- **No `~/.ssh` mount** by design — Anthropic recommends repo-scoped tokens. Add one only when a specific project actually needs SSH for git inside the container.
- **No `customizations.jetbrains.plugins` entry** — the official Claude Code JetBrains plugin is still Beta and its dotted bundle ID isn't published. IntelliJ devs install it manually once per dev container.

Per-IDE setup:

| IDE | Setup |
|---|---|
| VS Code / Cursor / Windsurf | Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) → open the repo → accept the "Reopen in Container" prompt. First time pulls the base image (~2min). The Claude Code extension auto-installs via `customizations.vscode.extensions`. |
| IntelliJ Ultimate / PyCharm Pro / WebStorm / GoLand | Dev Containers plugin is bundled. **File → Remote Development → Dev Containers → New Dev Container → From local project**, point at the repo's `.devcontainer/devcontainer.json`. Once attached, install the [Claude Code Beta plugin](https://plugins.jetbrains.com/plugin/27310-claude-code-beta-) inside the dev container. Plugin shells out to `claude` on PATH (already installed by the Feature). |
| IntelliJ Community editions | Dev Containers plugin is not bundled. Either upgrade to a paid edition or use Track A. |

### Stage 2 acceptance criteria

| # | Criterion | How to test | Status |
|---|---|---|---|
| 1 | Wiki mounts skip cleanly on hosts without the dir | On a host without `/Users/Shared/wikis/personal-wiki`, `claude_from_here` runs with no `-v /Users/Shared/wikis/personal-wiki:…` flag and creates no root-owned empty dir | ⬜ |
| 2 | Team alias build fails loudly without `HOST_HOME` | `docker build .` (no `--build-arg`) → error referencing `HOST_HOME` | ⬜ |
| 3 | Devcontainer reference builds clean | **Dev Containers: Rebuild Container** in `trading-journal` exits 0 | ⬜ |
| 4 | `claude` works in VS Code integrated terminal of devcontainer | `claude --version` returns version inside the container | ⬜ |
| 5 | Claude Code VS Code extension works inside devcontainer | Spark icon visible in Activity Bar, sign-in flow completes | ⬜ |
| 6 | Auth persists across `Rebuild Container` | Sign in once, rebuild, second open doesn't reprompt | ⬜ |
| 7 | Devcontainer flow works in IntelliJ Ultimate | New Dev Container from `.devcontainer/devcontainer.json` attaches, integrated terminal `claude` works | ⬜ |
| 8 | Claude Code JetBrains plugin works inside devcontainer | Plugin installed in-container, `Cmd+Esc` opens Claude, plugin reports the in-container `claude` binary | ⬜ |
| 9 | Rollout doc reviewed by a second Catenda dev | One teammate follows Track A or Track B from scratch; capture any friction in a follow-up | ⬜ |

---

## Future stages (deferred — pull in only on actual need)

Order is roughly the order in which we expect a real need to surface. None of these is being built proactively.

1. **PATH wiring** — done: `dotfiles/index.sh` sources `claude_sandbox/aliases.sh` via `shell/common.sh` (only when `docker` is on PATH). Multi-machine bootstrap (cloning dotfiles + sourcing `index.sh` from `~/.bashrc` / `~/.zshrc`) is a separate dotfiles follow-up.
2. **Session sync for `/insights`** — `docker cp` per-container `~/.claude/projects/` → host `~/.claude/projects/`. Trigger: first time we run Ralph and want host-side `/insights` to see those sessions.
3. **SSH usable inside the sandbox (push/pull from container)** — Stage 1 currently installs `openssh-client` and bind-mounts `~/.ssh:ro`, which is enough that `ssh` is *present*, but it still fails with `No user exists for uid 501` because the runtime UID has no `/etc/passwd` entry (the `getpwuid` gotcha called out in RESEARCH.md). Fix is the standard entrypoint pattern: `chmod 666 /etc/passwd /etc/group` at build, plus an entrypoint script that appends an entry for the runtime UID. Also mount `~/.gitconfig:ro` so repos without local-config user.name/email can still commit. **Deferred by design**: sandbox is commit-only for now; pull/push happen on host. Trigger to revisit: first time the sandbox-only flow gets annoying (e.g. running Ralph and needing to push from inside).
4. **`destroy` / volume teardown** — convenient flag for nuking a stale container or the auth volume. Trigger: enough clutter to bother us.
5. **Image upgrade story** — `build --pull` or separate `upgrade` step to bump the Claude CLI without a full rebuild from scratch. Trigger: first slow rebuild.
6. **Per-repo `.devcontainer/` overrides** — repo-specific `Dockerfile` extensions for Java JDK pin (trading-framework), CUDA + Ollama bridge (local-ai-lab). Trigger: these repos surface concrete needs.
7. **`--dangerously-skip-permissions` + firewall** — `init-firewall.sh` (iptables egress restriction) + AFK-mode toggle. Trigger: first time we want to actually go AFK with Ralph.
8. **MCP servers inside the container** — `.mcp.json` per-repo or baked into the image. Trigger: a workflow that genuinely needs MCP inside the sandbox.
9. **Wiki page** — `/Users/Shared/wikis/personal-wiki/wiki/ai/claude-code-sandboxing.md` once the pattern is stable. Trigger: Stage 2 done and used for a week.

---

## Appendix — v1 (archived as `experimental` tag)

The first version of this sandbox was a 7-subcommand bash wrapper (`build / up / shell / run / destroy / list / sync`) at `claude-settings/sandbox/claude-sandbox`. It worked but was over-engineered for the actual need; see the [`RESEARCH.md`](RESEARCH.md) decision notes.

**Snapshot:** git tag `experimental` on commit `eb8df0e`. Recover at any time:

```bash
git checkout experimental                  # full snapshot
git checkout experimental -- sandbox/      # only the sandbox dir
```

Things v1 had that we may want to revive in later stages:
- `sync` subcommand (~30 lines of bash; useful when Ralph sessions need to surface to host `/insights`)
- Container label convention (`claude-sandbox.project=<basename>`, `claude-sandbox.host_folder=<abs-path>`) for discovery
- Auth-via-named-volume approach (`claude-sandbox-config`) — superseded by host bind-mount of `~/.claude.json` + `~/.claude/` to keep file ownership on host user

Cut for now:
- `build / up / shell / run / destroy / list` subcommands — `docker` itself covers these adequately. Re-add only when a concrete daily pain point shows up.
