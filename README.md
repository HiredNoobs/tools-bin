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

## deployment

Tooling for deploying stacks to docker swarms or k8s clusters. This tooling is not generic and will only work with my stacks unless setup in the same way.

Each host manages a single orchestrator, configured with ``context-setup``:

```bash
context-setup swarm   # docker contexts
context-setup k8s     # kubeconfigs generated with talosctl into ~/.kube/contexts
```

Both install the Vault client, ``k8s`` also installs the pinned ``talosctl`` and ``kubectl`` versions into ``bin/`` if they're missing or a different version.

The k8s clusters run Talos, ``context-setup k8s`` creates a context for each talosconfig in ``~/.talos/contexts/<context>.yaml`` (e.g. ``production.core.yaml``), using the control plane IPs in it so it doesn't need DNS. Re-run it when the admin kubeconfig certificate expires. Talos enforces the ``baseline`` pod security standard, stacks that need more can set ``K8S_POD_SECURITY`` (e.g. ``privileged``) in their ``stack.env``.

This writes ``~/.config/bashrc/40-host`` which sets ``ORCHESTRATOR`` (plus the default context) for ``deployment``. The orchestrator specific parts of ``deployment`` live in ``bin/lib/orchestrators/<orchestrator>.sh``.

For k8s each stack is deployed to its own namespace, ``$K8S_NAMESPACE`` (``$STACK`` with ``_`` replaced by ``-``).

``secret-pack``, ``secret-unpack``, and ``secret-diff`` are python based helper scripts for deployment for reading and writing vault secrets.
