#!/usr/bin/env bash
#
# Docker swarm implementation of the orchestrator interface used by `deployment`.
# Every orchestrator must define the same orchestrator_* functions.

function orchestrator_contexts {
  docker context ls --format '{{ .Name }}' | grep -v 'default'
}

function orchestrator_use_context {
  export DOCKER_CONTEXT="$1"
}

# Prints the node JSON consumed by `export-roles`.
function orchestrator_nodes {
  docker node ls -q | xargs docker node inspect
}

function orchestrator_prepare {
  :
}

# Creates one swarm secret per key.
# Usage: orchestrator_create_external_secret <secret> <dir> <key>...
function orchestrator_create_external_secret {
  local secret dir key
  secret="$1"
  dir="$2"
  shift 2

  for key in "$@"; do
    docker secret create "external_${STACK}.${secret}_${key//./_}" "$dir/$key" > /dev/null
  done
}

function orchestrator_status {
  docker stack ps "$STACK"
}

function orchestrator_clean {
  local swarm_secrets swarm_secret

  log_info "Removing $STACK."
  docker stack rm "$STACK" --detach=false

  log_info "Removing $STACK external secrets."
  swarm_secrets=$(docker secret ls --format '{{ .ID }} {{ .Name }}' | grep "external_$STACK" | awk '{print $1}')
  for swarm_secret in $swarm_secrets; do
    docker secret rm "$swarm_secret" > /dev/null
  done
}

function orchestrator_purge {
  local nodes vols

  log_info "Waiting for volumes to detach..."
  sleep 10

  # This will potentially run against the same nodes multiple times
  # for stacks with mulitple containers on the same nodes.
  # Is this worth addressing?
  for var in $(compgen -e | grep '_FQDN_NODES$'); do
    nodes="${!var}"

    for host in $nodes; do
      log_warning "Checking $host for volumes..."
      vols=$(docker -H "ssh://$host" volume ls -q --filter "name=${STACK}_.*_data")

      if [[ -n "$vols" ]]; then
        log_warning "Deleting:"
        docker -H "ssh://$host" volume rm $vols
      fi
    done
  done
}
