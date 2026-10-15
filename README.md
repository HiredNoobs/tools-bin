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

Hyprland with a Quickshell desktop shell (``dotfiles/.config/quickshell``): the bar and its panels, notifications, launcher, lock screen, a matching SDDM login theme, and a settings window (``Super`` + ``I``) for sound, network, Bluetooth, displays, input, power, default apps, appearance and the shell itself.

The initial configuration was based on:

- Hyprland: [gaurav23b's simple-hyprland](https://github.com/gaurav23b/simple-hyprland)
- Wallpapers: [nordic-wallpapers](https://github.com/linuxdotexe/nordic-wallpapers)

### Keybinds

``Super`` + ``H`` lists every keybind. The main ones:

- ``Super`` + ``Space`` = Application launcher
- ``Super`` + ``I`` = Settings
- ``Super`` + ``Esc`` = Power menu
- ``Super`` + ``L`` = Lock
- ``Super`` + ``Tab`` = Workspace overview
- ``Super`` + ``V`` = Clipboard history
- ``Super`` + ``B`` = Wallpaper
- ``Print`` = Screenshot menu
- ``Super`` + ``Q`` = Close window
- ``Super`` + ``1``-``0`` = Workspace on the main monitor (``Ctrl`` for the second, ``Alt`` to move the window there)
- ``Super`` + ``T`` / ``W`` / ``E`` = Terminal / browser / files

</details>

## deployment

Tooling for deploying stacks to docker swarms. This tooling is not generic and will only work with my stacks unless setup in the same way.

``secret-pack``, ``secret-unpack``, and ``secret-diff`` are python based helper scripts for deployment for reading and writing vault secrets.
