# dotfiles

The dotfiles repository for shell customizations.

## Layout

- `bashrc`, `bash_profile` — shell config (PS1, kubectl/kubectx aliases, `*_from_here` docker aliases)
- `claude_sandbox/` — Claude Code sandbox (Dockerfile + `claude_from_here` alias). See `claude_sandbox/RESEARCH.md` and `claude_sandbox/PLAN.md`.

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
