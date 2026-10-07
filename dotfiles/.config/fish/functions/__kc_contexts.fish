# The kube contexts on this host (for kc and its completion).
function __kc_contexts
    set -l kube_contexts (set -q KUBE_CONTEXTS; and echo $KUBE_CONTEXTS; or echo ~/.kube/contexts)
    for config in $kube_contexts/*.yaml
        path change-extension '' (path basename $config)
    end
end
