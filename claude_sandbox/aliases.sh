# Source from your shell rc:
#   source ~/dev_workspace/dotfiles/claude_sandbox/aliases.sh
# (or rely on dotfiles/bashrc which sources it automatically)

# Run Claude in a sandboxed container against the current directory.
# Mirrors the convention of gcloud_from_here / terraform_from_here, with
# one addition: -u $(id -u):$(id -g) so any file Claude writes in the
# repo lands as the host user, not root. See RESEARCH.md "File ownership".
#
# HOME inside the container matches the host HOME (baked into the image
# via --build-arg HOST_HOME="$HOME"). That keeps host-absolute paths in
# ~/.claude/plugins/installed_plugins.json and the octo wikiHome config
# resolving the same way inside and outside the sandbox.
#
# Mounts:
#   $HOME/.claude.json → $HOME/.claude.json                   — auth/credentials
#   $HOME/.claude      → $HOME/.claude                        — config: skills, hooks, CLAUDE.md, settings, plugins
#   $HOME/dev_workspace/personal-wiki → same path             — wikiHome for the octo plugin
#   $HOME/.ssh         → $HOME/.ssh:ro                        — SSH keys for git
#   $(pwd)             → /mnt/folder                          — the repo we're working on
#
# Container is ephemeral (--rm); everything that needs to persist lives on host.
alias claude_from_here='docker run --rm -it \
  -u $(id -u):$(id -g) \
  -v "$HOME/.claude.json:$HOME/.claude.json" \
  -v "$HOME/.claude:$HOME/.claude" \
  -v "$HOME/dev_workspace/personal-wiki:$HOME/dev_workspace/personal-wiki" \
  -v "$HOME/.ssh:$HOME/.ssh:ro" \
  -v "$(pwd):/mnt/folder" \
  -w /mnt/folder \
  claude-sandbox claude'
