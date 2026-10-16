# `kc` shows or switches the kube (and Talos) context for this shell, as bash's kc does: one
# kubeconfig/talosconfig per cluster (see context-setup), selected with KUBECONFIG/TALOSCONFIG.
function kc --description 'Show or switch the kube/Talos context for this shell'
    set -l kube_contexts (set -q KUBE_CONTEXTS; and echo $KUBE_CONTEXTS; or echo ~/.kube/contexts)
    set -l talos_contexts (set -q TALOS_CONTEXTS; and echo $TALOS_CONTEXTS; or echo ~/.talos/contexts)
    set -l contexts (__kc_contexts)

    if test (count $argv) -eq 0
        set -l current
        if set -q KUBECONFIG
            set current (path change-extension '' (path basename $KUBECONFIG))
        end
        echo "Current context: $current"
        echo
        printf '%s\n' $contexts
    else if contains -- $argv[1] $contexts
        set -gx KUBECONFIG $kube_contexts/$argv[1].yaml
        set -gx TALOSCONFIG $talos_contexts/$argv[1].yaml
    else
        echo "Context $argv[1] does not exist on this host."
        return 1
    end
end
