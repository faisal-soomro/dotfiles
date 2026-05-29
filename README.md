# dotfiles

The dotfiles repository for shell customizations.

## Layout

- `index.sh` — single source of truth. Your shell rc sources this; it sources the fragments below.
- `shell/common.sh` — `*_from_here` docker aliases + `claude_from_here`
- `shell/kube.sh` — kubectl/kubectx aliases (`k`, `kg`, `kd`, `kx`, `kn`)
- `shell/prompt.sh` — cross-shell prompt: `git_branch` + `PS1` (bash) / `PROMPT` (zsh)
- `claude_sandbox/` — Claude Code sandbox (Dockerfile + `claude_from_here` alias). See `claude_sandbox/RESEARCH.md` and `claude_sandbox/PLAN.md`.

Each fragment lazy-stubs aliases whose binary is missing: sourcing on a machine without
`docker`/`kubectl`/`kubectx` is silent, and the alias prints `<name>: <dep> not installed`
only when you actually run it.

## Wiring it into your shell

Add one line to your live shell rc (the repo is **not** auto-loaded):

```bash
# ~/.bashrc (Linux) or ~/.zshrc (macOS)
source "$HOME/dev_workspace/dotfiles/index.sh"
```

The prompt fragment sets the prompt for whichever shell sources it — no oh-my-zsh
required. If you still have oh-my-zsh active, source `index.sh` **after** it so the
repo's `PROMPT` wins.

## Acceptance criteria

After wiring `index.sh` into your shell rc, a working install satisfies all of these:

- [ ] Opening a new shell prints no errors or warnings from sourcing `index.sh`.
- [ ] `echo $?` immediately after `source index.sh` returns `0` in both bash and zsh.
- [ ] The prompt shows `user cwd git:(branch) >> ` with bold-blue parens, red branch.
- [ ] In a dirty repo the prompt appends a yellow ` ✗`; in a clean repo it doesn't.
- [ ] Outside a git repo the prompt has no `git:(…)` segment.
- [ ] With `docker` installed, `gcloud_from_here` (and the other `*_from_here`) expand
      to a `docker run` command (`type gcloud_from_here`).
- [ ] With `docker` **un**installed, running `gcloud_from_here` prints
      `gcloud_from_here: docker not installed` and exits `127` — no warning at startup.
- [ ] Same lazy-stub behavior for `k`/`kg`/`kd` (depend on `kubectl`) and `kx`/`kn`
      (depend on `kubectx`/`kubens`).
- [ ] `claude_from_here` runs the sandbox image when `docker` is installed and the
      `claude-sandbox` image has been built (see [One-time setup](#one-time-setup)).

## `*_from_here` aliases

`shell/common.sh` defines `*_from_here` aliases (`alpine`, `kali`, `go`, `python3`, `gcloud`,
`terraform`, `aws`, `prowler`) that run a tool in an ephemeral container against `$(pwd)`.

> ⚠️ These were carried over from an old shell config and are **stale / unverified** — image
> tags, mount paths, and the gcloud credential mount all need a test pass before relying on them.

## One-time setup

Build the Claude sandbox image:

```bash
docker build \
  --build-arg HOST_HOME="$HOME" \
  -t claude-sandbox \
  ~/dev_workspace/dotfiles/claude_sandbox/
```

`HOST_HOME` is baked into the image so host-absolute paths inside `~/.claude/` (plugin install paths, octo `wikiHome`) resolve identically inside the container. Rebuild if you move to a machine with a different `$HOME`.

After that, `claude_from_here` works in any directory.
