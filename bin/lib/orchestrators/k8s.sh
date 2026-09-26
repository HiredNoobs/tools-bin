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
LONGHORN_NAMESPACE="${LONGHORN_NAMESPACE:-longhorn-system}"

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

# -----------------------------------------------------
# k8s only helpers
# -----------------------------------------------------

# Exits unless Longhorn (stack-longhorn) is running and has somewhere to put replicas.
# Stacks with Longhorn volumes call it at the start of stack_deploy, the StorageClass
# alone isn't enough as it's left behind if Longhorn is removed.
# Usage: k8s_require_longhorn [storage class]
function k8s_require_longhorn {
  local storage_class="${1:-longhorn}" provisioner daemonset desired ready disks

  provisioner=$(kubectl get storageclass "$storage_class" -o jsonpath='{.provisioner}' 2> /dev/null)

  if [[ -z "$provisioner" ]]; then
    log_error "StorageClass '$storage_class' doesn't exist, deploy stack-longhorn first."
    exit 1
  fi

  if [[ "$provisioner" != "driver.longhorn.io" ]]; then
    log_error "StorageClass '$storage_class' isn't a Longhorn StorageClass ($provisioner)."
    exit 1
  fi

  for daemonset in longhorn-manager longhorn-csi-plugin; do
    read -r desired ready <<< "$(kubectl get daemonset "$daemonset" --namespace "$LONGHORN_NAMESPACE" \
      -o jsonpath='{.status.desiredNumberScheduled} {.status.numberReady}' 2> /dev/null)"

    if [[ -z "$desired" || "$desired" -eq 0 || "$ready" != "$desired" ]]; then
      log_error "Longhorn isn't running, $daemonset has ${ready:-0}/${desired:-0} pods ready. Check stack-longhorn."
      exit 1
    fi
  done

  # Only nodes with a longhorn_disk (iac-homelab) get a disk.
  disks=$(kubectl get nodes.longhorn.io --namespace "$LONGHORN_NAMESPACE" -o json \
          | jq '[.items[] | select(.spec.allowScheduling) | .spec.disks[] | select(.allowScheduling)] | length')

  if [[ -z "$disks" || "$disks" -eq 0 ]]; then
    log_error "Longhorn has no schedulable disks, check the nodes have a longhorn_disk in iac-homelab."
    exit 1
  fi
}

# Warns if kube-vip (stack-kube-vip) isn't running. Without it LoadBalancer IPs aren't
# announced, only access from outside the cluster is lost so it doesn't stop the deploy.
# Stacks with a LoadBalancer IP call it from stack_deploy.
function k8s_warn_kube_vip {
  local running

  running=$(kubectl get daemonset --all-namespaces --selector app.kubernetes.io/name=kube-vip -o json 2> /dev/null \
            | jq '[.items[].status | select(.desiredNumberScheduled > 0 and .numberReady == .desiredNumberScheduled)] | length')

  if [[ -z "$running" || "$running" -eq 0 ]]; then
    log_warning "kube-vip isn't running, the LoadBalancer IP won't be reachable from outside the cluster until stack-kube-vip is deployed."
  fi
}
