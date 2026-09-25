#!/usr/bin/env bash
#
# Kubernetes implementation of the orchestrator interface used by `deployment`.
# Every orchestrator must define the same orchestrator_* functions.
#
# Each context is a standalone kubeconfig in $KUBE_CONTEXTS (see `context-setup k8s`),
# switching context is done by pointing KUBECONFIG at it - the same way DOCKER_CONTEXT
# is used for swarm. Each stack is deployed into its own namespace, $K8S_NAMESPACE.
#
# Clusters run Talos, which enforces the "baseline" pod security standard on every
# namespace. Stacks needing host networking/ports or privileged containers can set
# K8S_POD_SECURITY (e.g. "privileged") in their stack.env to relax it.

KUBE_CONTEXTS="${KUBE_CONTEXTS:-$HOME/.kube/contexts}"
TALOS_CONTEXTS="${TALOS_CONTEXTS:-$HOME/.talos/contexts}"

function orchestrator_contexts {
  local config
  for config in "$KUBE_CONTEXTS"/*.yaml; do
    [[ -f "$config" ]] && basename "$config" .yaml
  done
}

function orchestrator_use_context {
  export KUBECONFIG="$KUBE_CONTEXTS/$1.yaml"
  export TALOSCONFIG="$TALOS_CONTEXTS/$1.yaml"

  # Namespaces must be RFC 1123 labels, e.g. vault_core -> vault-core
  K8S_NAMESPACE="${STACK//_/-}"
  export K8S_NAMESPACE="${K8S_NAMESPACE,,}"
}

# Prints the node JSON consumed by `export-roles`.
function orchestrator_nodes {
  kubectl get nodes -o json
}

function orchestrator_prepare {
  kubectl create namespace "$K8S_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

  if [[ -n "${K8S_POD_SECURITY:-}" ]]; then
    kubectl label namespace "$K8S_NAMESPACE" --overwrite \
      "pod-security.kubernetes.io/enforce=$K8S_POD_SECURITY" > /dev/null
  fi
}

# Creates (or updates) a single k8s secret holding every key.
# Usage: orchestrator_create_external_secret <secret> <dir> <key>...
function orchestrator_create_external_secret {
  local secret dir key from_files
  secret="$1"
  dir="$2"
  shift 2
  from_files=()

  for key in "$@"; do
    from_files+=("--from-file=${key}=${dir}/${key}")
  done

  [[ ${#from_files[@]} -eq 0 ]] && return 0

  kubectl create secret generic "external-${secret//_/-}" \
    --namespace "$K8S_NAMESPACE" "${from_files[@]}" \
    --dry-run=client -o yaml | kubectl apply -f - > /dev/null
}

function orchestrator_status {
  kubectl get all,pvc --namespace "$K8S_NAMESPACE"
}

# Deleting the namespace removes everything in it, including external secrets.
function orchestrator_clean {
  log_info "Removing $STACK (namespace $K8S_NAMESPACE)."
  kubectl delete namespace "$K8S_NAMESPACE" --ignore-not-found --wait=true
}

# PVCs go with the namespace, this removes any PVs left behind by a Retain policy.
function orchestrator_purge {
  local pvs

  pvs=$(kubectl get pv -o json \
        | jq -r --arg ns "$K8S_NAMESPACE" '.items[] | select(.spec.claimRef.namespace == $ns) | .metadata.name')

  if [[ -n "$pvs" ]]; then
    log_warning "Deleting persistent volumes:"
    list "$pvs"
    kubectl delete pv $pvs --wait=true
    log_warning "Retained volumes may still have data on the backing storage."
  else
    log_info "No persistent volumes left for $K8S_NAMESPACE."
  fi
}
