# GIT FUNCTIONS
git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# TERMINAL PROMPT
PS1="\[\e[0;93m\]\u\[\e[m\]"                 # username
PS1+=" "                                     # space
PS1+="\[\e[0;95m\]\W\[\e[m\]"                # current directory
PS1+="\[\e[0;92m\]\$(git_branch)\[\e[m\]"    # current branch
PS1+=" "                                     # space
PS1+=">> "                                   # end prompt
export PS1;
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad


# Kubernetes aliases
alias k="kubectl"
alias kg="kubectl get"
alias kd="kubectl describe"

# kubectx aliases, install kubectx first (github: https://github.com/ahmetb/kubectx)
alias kx="kubectx"
alias kn="kubens"

# docker aliases, make sure to install docker first or any other container engine which use docker client
alias gcloud_from_here='docker run --rm -v ~/.config/gcloud:/root/.config/gcloud -v "$(pwd)":/mnt/folder -it google/cloud-sdk /bin/bash'
alias terraform_from_here='docker run --rm -v ~/.config/gcloud:/root/.config/gcloud -v "$(pwd)":/mnt/folder -it --entrypoint=/bin/sh hashicorp/terraform:1.10'