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

Hyprland: [gaurav23b's simple-hyprland](https://github.com/gaurav23b/simple-hyprland)
Hyprland: [end-4's dotfiles](https://github.com/end-4/dots-hyprland)
Waybar: [elifouts' dotfiles](https://github.com/elifouts/Dotfiles)
Wallpapers: [nordic-wallpapers](https://github.com/linuxdotexe/nordic-wallpapers)
Notification center: [ML4W dotfiles](https://github.com/mylinuxforwork/dotfiles)
Walker: [Maciejonos's dotfiles](https://github.com/Maciejonos/dotfiles)

### Keybinds

Window control:

- `Super` + `Q` = Kill window
- `Super` + `1` = Move to workspace 1, replace 1 with any other number 0-9.
- `Super` + `Alt` + `1` = Move current window to workspace 1, replace 1 with any other number 0-9.
- `Super` + `Shift` + `←` = Move current window left
- `Super` + `Shift` + `↓` = Move current window down
- `Super` + `Shift` + `↑` = Move current window up
- `Super` + `Shift` + `→` = Move current window right

Application shortcuts:

- `Super` = Application launcher
- `Super` + `W` = Web browser
- `Super` + `E` = File explorer
- `Super` + `T` = Terminal

</details>

## deployment

Tooling for deploying stacks to docker swarms. This tooling is not generic and will only work with my stacks unless setup in the same way.

``secret-pack``, ``secret-unpack``, and ``secret-diff`` are python based helper scripts for deployment for reading and writing vault secrets.
