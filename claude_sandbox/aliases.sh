# Source from your shell rc:
#   source ~/dev_workspace/dotfiles/claude_sandbox/aliases.sh
# (or rely on dotfiles/bashrc which sources it automatically)

# Run Claude in a sandboxed container against the current directory.
# Mirrors the convention of gcloud_from_here / terraform_from_here, with
# one addition: -u $(id -u):$(id -g) so any file Claude writes in the
# repo lands as the host user, not root. See RESEARCH.md "File ownership".
#
# Mounts:
#   $HOME/.claude.json → /home/me/.claude.json   — auth/credentials
#   $HOME/.claude      → /home/me/.claude        — config: skills, hooks, CLAUDE.md, settings, plugins
#   $HOME/dev_workspace → $HOME/dev_workspace:ro — resolves absolute-path symlinks inside ~/.claude/
#   $(pwd)             → /mnt/folder             — the repo we're working on
#
# Container is ephemeral (--rm); everything that needs to persist lives on host.
alias claude_from_here='docker run --rm -it \
  -u $(id -u):$(id -g) \
  -e HOME=/home/me \
  `# Highly use-case-specific: forwarded so the wiki hooks in settings.json` \
  `# can resolve $WIKI_HOME/scripts/...sh. Remove or adapt for other setups.` \
  -e WIKI_HOME="$WIKI_HOME" \
  -v "$HOME/.claude.json:/home/me/.claude.json" \
  -v "$HOME/.claude:/home/me/.claude" \
  -v "$HOME/.ssh:/home/me/.ssh:ro" \
  -v "$HOME/dev_workspace:$HOME/dev_workspace:ro" \
  -v "$(pwd):/mnt/folder" \
  -w /mnt/folder \
  claude-sandbox claude'
