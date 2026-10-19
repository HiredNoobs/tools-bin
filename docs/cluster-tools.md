# Cluster tools

## Contexts

``context-setup`` configures the Talos clusters this host manages: a kube context for each talosconfig in ``~/.talos/contexts/<context>.yaml`` (e.g. ``production.core.yaml``), generated with ``talosctl`` into ``~/.kube/contexts``, using the control plane IPs in the talosconfig so it doesn't need DNS. Re-run it when the admin kubeconfig certificate expires (a year). It also installs the Vault client and the pinned ``talosctl``, ``kubectl`` and ``flux`` into ``bin/``.

It writes the default context to ``~/.config/bashrc/40-host`` and ``~/.config/fish/conf.d/40-host.fish``. ``kc`` switches context per shell (below).

``secret-merge`` and ``secret-compare`` are self-contained filters on a secret as a flat JSON object of strings (stdin/stdout, usable on their own), used by ``vsecret``: ``secret-merge`` applies ``KEY=VALUE``, ``KEY=@FILE``, generated keys (``--generate N``) and ``--unset KEY``; ``secret-compare OLD NEW`` prints the keys added, changed and removed (names only), exit 0 for none, 1 for changes, 2 if NEW isn't a secret.

``make-ca``, ``make-cert``, ``make-keystore`` and ``make-truststore`` create a CA, certificates signed by it, and Java keystores/truststores (openssl, keytool).

## Tools

For the apps on Flux, run against the current kubectl context. Each prints its full usage with ``help``.

- ``vsecret``: Vault secrets in ``labv2`` for the one-key-per-secret layout (``labv2/<env>/<app>``, a path without ``/`` is in ``production/``). ``ls``, ``get``, ``set`` (merges keys; ``KEY=VALUE``, ``KEY=@FILE``, or a hidden prompt; ``--generate [N]``, 32 by default), ``unset`` and ``edit`` (in ``$EDITOR``). Every write is check-and-set against the version it read, and force-syncs the ExternalSecrets reading that path (``--no-sync`` to skip). A file-shaped secret is one key: ``vsecret set redis ca.crt=@ca.crt``, ``vsecret get redis ca.crt > ca.crt``. The changes themselves are worked out by ``secret-merge`` and ``secret-compare``.
- ``redis``: ``redis-cli`` as the admin user in the master's pod (interactive without arguments): the one the sentinels name when Redis runs with Sentinel, else ``redis-0``. Plus ``redis scan-delete <pattern>``, ``redis SENTINEL <subcommand>`` (e.g. ``redis SENTINEL master redis``) goes to a sentinel, ``redis sentinel`` alone is interactive against one, and ``redis --pod <pod> ...`` for a given pod (a replica). The admin password is ``labv2/production/redis`` ``REDIS_ADMIN_PASSWORD``.
- ``kc`` (a shell function, bash and fish): shows or switches this shell's kube and Talos context (``kc production.core``).
- ``kns``: shows the current context's namespace and the cluster's namespaces, or sets it (``kns redis``, tab completes), so ``kubectl`` doesn't need ``-n``. It's saved in the context's kubeconfig, so it applies to every shell on that context.
- ``deployment status [namespace]``: like ``docker stack ps``, each pod's containers one per line: the image they run (``name:tag``), the node, their state and restarts. Every namespace without one.
- ``deployment longhorn_backup``: a Longhorn system backup before an upgrade (a new backup of every volume, then Longhorn's own resources, to its backup target), followed until it's ready or fails. Once it's ready it replaces the one it made last time (so there's one; a failed run keeps the last good one). The volume backups it makes (``system-backup-*``) are left to manage by hand.
- ``rabbitmq``: ``rabbitmqctl`` in ``rabbitmq-0``, ``rabbitmq diag`` for ``rabbitmq-diagnostics``, ``rabbitmq plugins`` for ``rabbitmq-plugins``. Users and permissions are in git (the Topology Operator), not made here.
