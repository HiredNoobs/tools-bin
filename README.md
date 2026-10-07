# bin

Repo contains my dotfiles and various scripts that are added to the path.

This is both for my servers and daily drivers, though some scripts will be for one or the other.

## Move in

**This script only supports debian!** It's main use is setting up debian LXCs for other use cases just clone the repo.

``movein.sh`` is for the initial setup - it sets up a new user with sudo access and clones this repo to it's home directory.

``movein.sh`` is intended to be run as ``root`` on the first login to a new host/VM/LXC.

``movein.sh`` usage:

```bash
curl -L https://raw.githubusercontent.com/HiredNoobs/tools-bin/refs/heads/master/bin/movein.sh | bash -s [username]
```

After running you should update the password for the new user with ``passwd [username]``.

## Setup

``setup`` is for installing optional extras and configuring them. ``setup`` may expect access to ``sudo`` for some options.

``setup`` usage:

```bash
setup COMMAND
```

``setup help`` can be used to see all the available options. Some of them can be seen below.

<details><summary>Bash</summary>

Configure bash with ``bashrc``. The bashrc is mostly a wrapper to load content from ``.config/bashrc``.

This does add this repo to the ``$PATH``.

</details>

<details><summary>Hyprland</summary>

For Arch only.

Included is a very basic Hyprland configuration.

The initial confiuration is based on the following repos:

- Hyprland + wlogout: [gaurav23b's simple-hyprland](https://github.com/gaurav23b/simple-hyprland)
- Waybar: [elifouts' dotfiles](https://github.com/elifouts/Dotfiles)
- Waybar network context menu: [cebem1nt's dotfiles](https://github.com/cebem1nt/dotfiles)
- Wallpapers: [nordic-wallpapers](https://github.com/linuxdotexe/nordic-wallpapers)

### Keybinds

Window control:

- `Super` + `Q` = Kill window
- `Super` + `1` = Move to workspace 1, replace 1 with any other number 0-9.
- `Super` + `Alt` + `1` = Move current window to workspace 1, replace 1 with any other number 0-9.
- `Super` + `Shift` + `←` = Move current window left
- `Super` + `Shift` + `↓` = Move current window down
- `Super` + `Shift` + `↑` = Move current window up
- `Super` + `Shift` + `→` = Move current window right
- `Super` + `LMB` = drag window

Application shortcuts:

- `Super` = Application launcher
- `Super` + `W` = Web browser
- `Super` + `E` = File explorer
- `Super` + `T` = Terminal
- `Super` + `C` = Code editor

</details>

## Contexts

``context-setup`` configures the Talos clusters this host manages: a kube context for each talosconfig in ``~/.talos/contexts/<context>.yaml`` (e.g. ``production.core.yaml``), generated with ``talosctl`` into ``~/.kube/contexts``, using the control plane IPs in the talosconfig so it doesn't need DNS. Re-run it when the admin kubeconfig certificate expires (a year). It also installs the Vault client and the pinned ``talosctl``, ``kubectl`` and ``flux`` into ``bin/``.

It writes the default context to ``~/.config/bashrc/40-host`` and ``~/.config/fish/conf.d/40-host.fish``. ``kc`` switches context per shell (below).

``secret-merge`` and ``secret-compare`` are self-contained filters on a secret as a flat JSON object of strings (stdin/stdout, usable on their own), used by ``vsecret``: ``secret-merge`` applies ``KEY=VALUE``, ``KEY=@FILE``, generated keys (``--generate N``) and ``--unset KEY``; ``secret-compare OLD NEW`` prints the keys added, changed and removed (names only), exit 0 for none, 1 for changes, 2 if NEW isn't a secret.

``make-ca``, ``make-cert``, ``make-keystore`` and ``make-truststore`` create a CA, certificates signed by it, and Java keystores/truststores (openssl, keytool).

## Cluster tools

For the apps on Flux, run against the current kubectl context. Each prints its full usage with ``help``.

- ``vsecret``: Vault secrets in ``labv2`` for the one-key-per-secret layout (``labv2/<env>/<app>``, a path without ``/`` is in ``production/``). ``ls``, ``get``, ``set`` (merges keys; ``KEY=VALUE``, ``KEY=@FILE``, or a hidden prompt; ``--generate N``), ``unset`` and ``edit`` (in ``$EDITOR``). Every write is check-and-set against the version it read, and force-syncs the ExternalSecrets reading that path (``--no-sync`` to skip). A file-shaped secret is one key: ``vsecret set redis ca.crt=@ca.crt``, ``vsecret get redis ca.crt > ca.crt``. The changes themselves are worked out by ``secret-merge`` and ``secret-compare``.
- ``redis``: ``redis-cli`` as the admin user in ``redis-0`` (interactive without arguments), plus ``redis scan-delete <pattern>``. The admin password is ``labv2/production/redis`` ``REDIS_ADMIN_PASSWORD``.
- ``kc`` (a shell function, bash and fish): shows or switches this shell's kube and Talos context (``kc production.core``).
- ``kns``: shows the current context's namespace and the cluster's namespaces, or sets it (``kns redis``, tab completes), so ``kubectl`` doesn't need ``-n``. It's saved in the context's kubeconfig, so it applies to every shell on that context.
- ``rabbitmq``: ``rabbitmqctl`` in ``rabbitmq-0``, ``rabbitmq diag`` for ``rabbitmq-diagnostics``, ``rabbitmq plugins`` for ``rabbitmq-plugins``. Users and permissions are in git (the Topology Operator), not made here.

## Prompt

bash and fish share one [Starship](https://starship.rs) prompt, ``dotfiles/.config/starship.toml`` (``setup bash`` / ``setup fish`` install it, a pinned release on Debian). Two lines: linked ``[...]`` segments above for what applies (the kube context, red for production, with the namespace from ``kns``; the git branch and status; slow commands; a failed command's exit code; background jobs), an active Python venv, the directory and ``$`` (``#`` as root) below. With nothing for the first line it's just the second. Plain text and box drawing characters, no Nerd Font needed. Without Starship, bash falls back to a plain version.
