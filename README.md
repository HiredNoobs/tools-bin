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

``setup help`` can be used to see all the available options (Hyprland's is in [docs](docs/hyprland.md)). Some of them can be seen below.

<details><summary>Bash</summary>

Configure bash with ``bashrc``. The bashrc is mostly a wrapper to load content from ``.config/bashrc``.

This does add this repo to the ``$PATH``.

</details>

## New machine

- A Debian host, VM or LXC: ``movein.sh`` (above), then ``setup bash`` or ``setup fish``. The prx-999 VMs get this from Ansible (iac-homelab's ``movein`` role), the management VM its contexts too (``mgmt.yml``).
- Anything else: clone the repo, then ``setup bash`` / ``setup fish``. With talosconfigs in ``~/.talos/contexts/`` (iac-homelab's ``./build.sh clusters`` writes them), ``context-setup`` for the cluster tools.

## Tools

| Tool | Does |
| --- | --- |
| ``context-setup`` | A kube context for each Talos cluster this host manages, and the pinned ``talosctl``, ``kubectl``, ``flux`` and Vault client. |
| ``kc``, ``kns`` | Switch this shell's kube and Talos context, and the context's namespace. |
| ``vsecret`` | Vault secrets in ``labv2``, synced to the cluster's ExternalSecrets. |
| ``deployment`` | ``deployment status``: each pod's containers, image, node and state. ``deployment longhorn_backup``: a Longhorn system backup before an upgrade. |
| ``redis``, ``rabbitmq`` | Their admin CLIs in the cluster. |
| ``secret-merge``, ``secret-compare`` | Filters on a secret as JSON, used by ``vsecret``. |
| ``make-ca``, ``make-cert``, ``make-keystore``, ``make-truststore`` | A CA, certificates signed by it, Java keystores and truststores. |
| ``content-dl`` | Audio or video from a URL with yt-dlp, into ``~/Downloads``. |

## More

| Page | Covers |
| --- | --- |
| [Cluster tools](docs/cluster-tools.md) | ``context-setup`` and the cluster tools above in detail. |
| [Prompt](docs/prompt.md) | The Starship prompt bash and fish share. |
| [Hyprland](docs/hyprland.md) | The Arch Hyprland setup and its keybinds. |
