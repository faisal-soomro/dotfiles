# Cross-shell prompt: git_branch + PS1/PROMPT setup, no oh-my-zsh required.
# Non-printing escapes need different markers per shell so width math stays
# correct: bash uses \001/\002 (the readline form of \[ \]); zsh uses %{ %}
# under PROMPT_SUBST.

if [ -n "$ZSH_VERSION" ]; then
    _PS_S='%{'; _PS_E='%}'
elif [ -n "$BASH_VERSION" ]; then
    _PS_S=$'\001'; _PS_E=$'\002'
fi

# git_branch: prints ' git:(branch)' (+ ' ✗' when dirty), colored like
# oh-my-zsh's robbyrussell theme: bold-blue git:(), red branch, yellow ✗.
git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return

    local s=$_PS_S e=$_PS_E esc=$'\033'
    local blue="${s}${esc}[1;34m${e}" red="${s}${esc}[31m${e}"
    local yellow="${s}${esc}[33m${e}" reset="${s}${esc}[0m${e}"

    if git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
        printf ' %sgit:(%s%s%s)%s' "$blue" "$red" "$branch" "$blue" "$reset"
    else
        printf ' %sgit:(%s%s%s) %s✗%s' "$blue" "$red" "$branch" "$blue" "$yellow" "$reset"
    fi
}

if [ -n "$ZSH_VERSION" ]; then
    setopt PROMPT_SUBST
    PROMPT='%F{yellow}%n%f %F{magenta}%1~%f$(git_branch) >> '
elif [ -n "$BASH_VERSION" ]; then
    PS1="\[\e[0;93m\]\u\[\e[m\] \[\e[0;95m\]\W\[\e[m\]\$(git_branch) >> "
    export PS1
    export CLICOLOR=1
    export LSCOLORS=ExFxBxDxCxegedabagacad
fi
