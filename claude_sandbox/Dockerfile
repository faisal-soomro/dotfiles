FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates git openssh-client \
 && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g @anthropic-ai/claude-code

# World-writable HOME so the container can run as any host UID/GID
# (see RESEARCH.md "File ownership"). The runtime user has no /etc/passwd
# entry; tools that call getpwuid() may warn — fix only if it bites.
RUN mkdir -p /home/me && chmod 777 /home/me

# Point npm's global prefix into HOME so runtime `npm i -g` works as
# a non-root UID without falling back to /usr/local.
RUN npm config set prefix /home/me/.npm-global --global
ENV PATH=/home/me/.npm-global/bin:$PATH

WORKDIR /mnt/folder
