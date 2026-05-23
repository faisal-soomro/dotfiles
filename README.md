# dotfiles

The dotfiles repository for shell customizations.

## Layout

- `bashrc`, `bash_profile` — shell config (PS1, kubectl/kubectx aliases, `*_from_here` docker aliases)
- `claude_sandbox/` — Claude Code sandbox (Dockerfile + `claude_from_here` alias). See `claude_sandbox/RESEARCH.md` and `claude_sandbox/PLAN.md`.

## One-time setup

Build the Claude sandbox image:

```bash
docker build -t claude-sandbox ~/dev_workspace/dotfiles/claude_sandbox/
```

After that, `claude_from_here` works in any directory.
