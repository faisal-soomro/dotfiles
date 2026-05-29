# Kubernetes aliases. Each group depends on its binary; missing ones get a
# lazy stub (see _stub_missing in index.sh) that warns only when invoked.
if command -v kubectl >/dev/null 2>&1; then
    alias k="kubectl"
    alias kg="kubectl get"
    alias kd="kubectl describe"
else
    _stub_missing kubectl k kg kd
fi

# kubectx ships two binaries: kubectx (kx) and kubens (kn).
command -v kubectx >/dev/null 2>&1 && alias kx="kubectx" || _stub_missing kubectx kx
command -v kubens  >/dev/null 2>&1 && alias kn="kubens"  || _stub_missing kubens kn
