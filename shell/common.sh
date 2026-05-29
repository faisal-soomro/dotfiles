# Shell-agnostic config sourced (via index.sh) by both bash and zsh.
# No `set -euo pipefail` here — this is sourced into interactive shells.

# The *_from_here aliases and claude_from_here all need docker. If docker is
# absent, lazy-stub them (see _stub_missing in index.sh) so they warn on use
# rather than failing with a cryptic "command not found".
if command -v docker >/dev/null 2>&1; then
    # Run a tool in an ephemeral (--rm) container against the current directory.
    # NOTE: these are stale and unverified — see README "*_from_here aliases".
    alias alpine_from_here='docker run --rm -v "$(pwd)":/mnt/folder -it alpine:edge /bin/sh'
    alias kali_from_here='docker run --rm -v "$(pwd)":/mnt/folder -it kalilinux/kali-rolling /bin/bash'
    alias go_from_here='docker run --rm -v "$(pwd)":/mnt/folder -it golang:alpine /bin/sh'
    alias python3_from_here='docker run --rm -v "$(pwd)":/mnt/folder -it python:3 /bin/bash'
    alias gcloud_from_here='docker run --rm -v ~/.config/gcloud:/root/.config/gcloud -v "$(pwd)":/mnt/folder -it google/cloud-sdk /bin/bash'
    alias terraform_from_here='docker run --rm -v ~/.config/gcloud:/root/.config/gcloud -v "$(pwd)":/mnt/folder -it --entrypoint=/bin/sh hashicorp/terraform:1.10'
    alias aws_from_here='docker run --rm -v "$(pwd)":/mnt/folder -it --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env AWS_SESSION_TOKEN --env AWS_REGION --entrypoint /bin/bash amazon/aws-cli:latest'
    alias prowler_from_here='docker run --rm --platform linux/x86_64 -it -v /tmp/prowler-output:/home/prowler/output -p 127.0.0.1:11666:11666 --env HOST=0.0.0.0 --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env AWS_SESSION_TOKEN public.ecr.aws/prowler-cloud/prowler:stable'

    docker_from_here() {
        docker run --rm -v "$(pwd)":/mnt/folder -it "${1}" /bin/sh
    }

    # claude_from_here — see claude_sandbox/RESEARCH.md
    [ -f "$HOME/dev_workspace/dotfiles/claude_sandbox/aliases.sh" ] && source "$HOME/dev_workspace/dotfiles/claude_sandbox/aliases.sh"
else
    _stub_missing docker \
        alpine_from_here kali_from_here go_from_here python3_from_here \
        gcloud_from_here terraform_from_here aws_from_here prowler_from_here \
        docker_from_here claude_from_here
fi
