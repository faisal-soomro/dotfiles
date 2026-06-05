FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates git openssh-client jq \
      ripgrep fd-find gh trash-cli \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g @anthropic-ai/claude-code

# HOME is baked to match the host HOME so the host-absolute installPath
# inside ~/.claude/plugins/installed_plugins.json resolves identically
# inside the container — no /home/me indirection. (Wiki paths under
# /Users/Shared/wikis/ are mounted same-path and don't depend on HOST_HOME.)
# Build with: --build-arg HOST_HOME="$HOME"
ARG HOST_HOME=/home/me

# World-writable HOME so the container can run as any host UID/GID
# (see RESEARCH.md "File ownership"). The runtime user has no /etc/passwd
# entry; tools that call getpwuid() may warn — fix only if it bites.
RUN mkdir -p "$HOST_HOME" && chmod 777 "$HOST_HOME"

# Point npm's global prefix into HOME so runtime `npm i -g` works as
# a non-root UID without falling back to /usr/local.
RUN npm config set prefix "$HOST_HOME/.npm-global" --global
# Claude Code self-check expects a real binary at ~/.local/bin/claude (not an
# npm shim). Run `claude install` at build time so it copies the standalone
# binary to that path and the /doctor warning never fires.
RUN mkdir -p "$HOST_HOME/.local/bin" \
 && HOME="$HOST_HOME" claude install
ENV HOME="$HOST_HOME"
ENV PATH="$HOST_HOME/.npm-global/bin:$HOST_HOME/.local/bin:$PATH"

WORKDIR /mnt/folder
