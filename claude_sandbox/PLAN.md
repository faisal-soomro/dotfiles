# Sandbox plan

Forward-looking plan for `dotfiles/claude_sandbox/` (previously `claude-settings/sandbox/` — moved here in the claude-settings home-as-repo migration). Two stages, each with explicit acceptance criteria before moving on. For the rationale behind these choices see [`RESEARCH.md`](RESEARCH.md).

Build only what we miss in practice. Don't add subcommands, flags, or features ahead of an actual need.

---

## Stage 1 — `claude_from_here` alias

Smallest viable sandbox. A Dockerfile and a single bash alias. No CLI wrapper.

### Build

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu base + node + `@anthropic-ai/claude-code` + `openssh-client`. **No baked-in user.** World-writable `/home/me` so the container can run as any host UID. npm prefix in HOME so runtime `npm i -g` has somewhere to land. |
| `aliases.sh` | One alias: `claude_from_here` that runs Claude as the host UID/GID against the current directory, bind-mounting `~/.claude.json`, `~/.claude/`, and `~/.ssh:ro` from host. |

The alias shape:

```bash
alias claude_from_here='docker run --rm -it \
  -u $(id -u):$(id -g) \
  -e HOME=/home/me \
  -e WIKI_HOME="$WIKI_HOME" \
  -v "$HOME/.claude.json:/home/me/.claude.json" \
  -v "$HOME/.claude:/home/me/.claude" \
  -v "$HOME/.ssh:/home/me/.ssh:ro" \
  -v "$HOME/dev_workspace:$HOME/dev_workspace:ro" \
  -v "$(pwd):/mnt/folder" \
  -w /mnt/folder \
  claude-sandbox claude'
```

Mounts, line by line:

| Mount | Why |
|---|---|
| `$HOME/.claude.json → /home/me/.claude.json` | Auth/credentials, mirrors `gcloud_from_here` convention |
| `$HOME/.claude → /home/me/.claude` | Config dir: skills, hooks, CLAUDE.md, settings, plugins |
| `$HOME/.ssh → /home/me/.ssh:ro` | SSH keys for `git pull` / `git push`. See RESEARCH.md "SSH credentials inside the sandbox" |
| `$HOME/dev_workspace → $HOME/dev_workspace:ro` | Resolves absolute-path symlinks inside `~/.claude/` that point at host paths |
| `$(pwd) → /mnt/folder` | The repo we're working on |

Why `-u $(id -u):$(id -g)` and `HOME=/home/me`: see RESEARCH.md "File ownership" — all files Claude writes must land as the host user, not root.

### Step-by-step build order

Per the global teaching-walkthrough rule (one file, one step, verify after each):

1. Write `Dockerfile` → build the image → verify the image exists (`docker images | grep claude-sandbox`)
2. Write `aliases.sh` → source it in a fresh shell → verify the alias resolves (`type claude_from_here`)
3. Run the alias against a low-stakes dir (e.g. `~/dev_workspace/trading-journal`) → Claude starts → either already authed (because host `~/.claude.json` is mounted in) or log in once
4. Exit. Touch a file from inside the container, exit, `ls -l` on host → confirm host-user ownership, not root
5. Re-run the alias in the same dir → confirm no re-login (auth shared via bind-mounted `~/.claude.json`)

### Stage 1 acceptance criteria

Don't move to Stage 2 until all of these pass.

| # | Criterion | How to test |
|---|---|---|
| 1 | Image builds clean | `docker build -t claude-sandbox ~/dev_workspace/dotfiles/claude_sandbox/` exits 0 |
| 2 | Alias resolves in a fresh shell | `type claude_from_here` returns the docker run line |
| 3 | Claude starts inside the container | `claude_from_here` opens the Claude CLI |
| 4 | Container runs as host UID | Inside: `id -u` matches host `id -u` (e.g. 501) |
| 5 | Repo files visible inside container | `ls /mnt/folder` shows the host directory contents |
| 6 | Edits in container appear on host | Touch a file inside; it shows up on host via `ls` |
| 7 | Host stays clean — no leakage from `pip` | Inside container: `pip install requests`. Outside: `which pip` either reports no host pip touched or a fresh `pip list` on host doesn't show `requests` |
| 8 | Host stays clean — no leakage from `npm -g` | Inside container: `npm install -g cowsay`. Outside: `which cowsay` returns nothing on host |
| 9 | Container is gone after exit | `docker ps -a --filter "ancestor=claude-sandbox"` returns no rows |
| 10 | Files created in container are host-owned | Inside: `touch /mnt/folder/ownership-test`. Outside: `ls -l ownership-test` shows host user, not root |
| 11 | Auth persists across runs | Run twice; second run skips login (because `~/.claude.json` is bind-mounted from host) |

If any of #5-#11 fail we stop and fix before continuing.

---

## Stage 2 — devcontainer layer on top

Once Stage 1 is solid, add a `.devcontainer/devcontainer.json` template that targets the **same image** and the **same host bind-mounts** so VS Code "Reopen in Container" lands in an identical environment to the terminal alias.

### Build

| File | Purpose |
|---|---|
| `devcontainer.json.template` | Reusable template engineers drop into any repo. Points at the `claude-sandbox` image, bind-mounts `~/.claude.json` and `~/.claude/` from host, runs as host UID. |
| `README.md` (update) | One-line install + how to drop the template into a repo. |

Template shape (subject to refinement during Stage 2):

```json
{
  "name": "claude-sandbox",
  "image": "claude-sandbox:latest",
  "workspaceFolder": "/mnt/folder",
  "workspaceMount": "source=${localWorkspaceFolder},target=/mnt/folder,type=bind",
  "mounts": [
    "source=${localEnv:HOME}/.claude.json,target=/home/me/.claude.json,type=bind",
    "source=${localEnv:HOME}/.claude,target=/home/me/.claude,type=bind"
  ],
  "containerEnv": { "HOME": "/home/me" },
  "updateRemoteUserUID": true
}
```

### Step-by-step build order

1. Author `devcontainer.json.template` → drop it as `.devcontainer/devcontainer.json` into `trading-journal` (smallest, lowest-stakes repo)
2. Open `trading-journal` in VS Code → run **Dev Containers: Reopen in Container** → confirm container starts and VS Code attaches
3. Open VS Code's integrated terminal → run `claude` → confirm it works without re-login (auth volume shared with Stage 1's terminal use)
4. Edit a file in VS Code → confirm host filesystem reflects it
5. Close VS Code container → reopen → confirm state retained
6. Repeat 1-5 in a second repo to validate the template is portable

### Stage 2 acceptance criteria

| # | Criterion | How to test |
|---|---|---|
| 1 | Template drops cleanly into a fresh repo | Copy file in, no edits needed |
| 2 | VS Code "Reopen in Container" succeeds | Status bar shows the devcontainer name, no errors |
| 3 | `claude` available inside VS Code terminal | `which claude` returns a path, `claude --version` runs |
| 4 | Auth shared with terminal alias | Already logged in on first VS Code launch (host `~/.claude.json` is the same file the terminal alias used) |
| 5 | Edits persist to host | Save a file in VS Code; host shows the change |
| 6 | Container survives VS Code close → reopen | State (installed packages, terminal history) intact unless rebuild was explicit |
| 7 | Cursor "Reopen in Container" also works | Same template, second editor — confirms portability |
| 8 | Pip/npm-g still don't leak to host | Same test as Stage 1 #7-#8, but via VS Code terminal |

---

## Future stages (deferred — pull in only on actual need)

Order is roughly the order in which we expect a real need to surface. None of these is being built proactively.

1. **PATH wiring** — ~~extend `claude-settings/install.sh`~~ done: `dotfiles/bashrc` sources `aliases.sh` automatically. Multi-machine bootstrap (cloning dotfiles + linking bashrc into `$HOME`) is a separate dotfiles-repo follow-up.
2. **Session sync for `/insights`** — `docker cp` per-container `~/.claude/projects/` → host `~/.claude/projects/`. Trigger: first time we run Ralph and want host-side `/insights` to see those sessions.
3. **SSH usable inside the sandbox (push/pull from container)** — Stage 1 currently installs `openssh-client` and bind-mounts `~/.ssh:ro`, which is enough that `ssh` is *present*, but it still fails with `No user exists for uid 501` because the runtime UID has no `/etc/passwd` entry (the `getpwuid` gotcha called out in RESEARCH.md). Fix is the standard entrypoint pattern: `chmod 666 /etc/passwd /etc/group` at build, plus an entrypoint script that appends an entry for the runtime UID. Also mount `~/.gitconfig:ro` so repos without local-config user.name/email can still commit. **Deferred by design**: sandbox is commit-only for now; pull/push happen on host. Trigger to revisit: first time the sandbox-only flow gets annoying (e.g. running Ralph and needing to push from inside).
4. **`destroy` / volume teardown** — convenient flag for nuking a stale container or the auth volume. Trigger: enough clutter to bother us.
5. **Image upgrade story** — `build --pull` or separate `upgrade` step to bump the Claude CLI without a full rebuild from scratch. Trigger: first slow rebuild.
6. **Per-repo `.devcontainer/` overrides** — repo-specific `Dockerfile` extensions for Java JDK pin (trading-framework), CUDA + Ollama bridge (local-ai-lab). Trigger: these repos surface concrete needs.
7. **`--dangerously-skip-permissions` + firewall** — `init-firewall.sh` (iptables egress restriction) + AFK-mode toggle. Trigger: first time we want to actually go AFK with Ralph.
8. **MCP servers inside the container** — `.mcp.json` per-repo or baked into the image. Trigger: a workflow that genuinely needs MCP inside the sandbox.
9. **Wiki page** — `personal-wiki/wiki/ai/claude-code-sandboxing.md` once the pattern is stable. Trigger: Stage 2 done and used for a week.

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
