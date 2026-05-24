# Source from your shell rc:
#   source ~/dev_workspace/dotfiles/claude_sandbox/aliases.sh
# (or rely on dotfiles/bashrc which sources it automatically)

# Run Claude in a sandboxed container against the current directory.
# Mirrors the convention of gcloud_from_here / terraform_from_here, with
# one addition: -u $(id -u):$(id -g) so any file Claude writes in the
# repo lands as the host user, not root. See RESEARCH.md "File ownership".
#
# Mounts:
#   $HOME/.claude.json → /home/me/.claude.json    — auth/credentials (HOME-relative lookup)
#   $HOME/.claude      → /home/me/.claude         — config: skills, hooks, CLAUDE.md, settings, plugins
#   $HOME/.claude.json → $HOME/.claude.json       — same file, mounted at host path so absolute paths resolve
#   $HOME/.claude      → $HOME/.claude            — same dir; installed_plugins.json bakes host-absolute installPaths
#   $HOME/dev_workspace/personal-wiki → same path — wikiHome (octo plugin) is configured as a host-absolute path
#   $(pwd)             → /mnt/folder              — the repo we're working on
#
# Container is ephemeral (--rm); everything that needs to persist lives on host.
alias claude_from_here='docker run --rm -it \
  -u $(id -u):$(id -g) \
  -e HOME=/home/me \
  -v "$HOME/.claude.json:/home/me/.claude.json" \
  -v "$HOME/.claude:/home/me/.claude" \
  -v "$HOME/.claude.json:$HOME/.claude.json" \
  -v "$HOME/.claude:$HOME/.claude" \
  -v "$HOME/dev_workspace/personal-wiki:$HOME/dev_workspace/personal-wiki" \
  -v "$HOME/.ssh:/home/me/.ssh:ro" \
  -v "$(pwd):/mnt/folder" \
  -w /mnt/folder \
  claude-sandbox claude'
