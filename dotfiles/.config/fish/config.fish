# The fish equivalent of ~/.config/bashrc, kept in step with it: the same environment, aliases,
# prompt (starship, ~/.config/starship.toml) and `kc`/`kns` (functions/, completions/).
# conf.d/40-host.fish is generated per host by context-setup (the kube/talos contexts).

# -----------------------------------------------------
# Environment (bashrc 00-init, 10-env)
# -----------------------------------------------------

set -gx EDITOR vim
set -gx TOOLS_BIN ~/tools-bin/bin
fish_add_path $TOOLS_BIN

set -gx ANSIBLE_HOST_KEY_CHECKING false

set -gx DOMAIN hirednoobs.com

set -gx VAULT_ADDR https://vault.$DOMAIN

if status is-interactive
    # No greeting
    set fish_greeting

    # For tmux
    set -gx SHELL (command -v fish)

    # -----------------------------------------------------
    # Aliases (bashrc 20-aliases)
    # -----------------------------------------------------

    alias tm "tmux new-session \; split-window -h -p 50 \; select-pane -L \; attach"

    if test "$TERM" = xterm-kitty
        alias ssh "kitty +kitten ssh"
    end

    # -----------------------------------------------------
    # Prompt (bashrc 30-customisation)
    # -----------------------------------------------------

    if command -q starship
        starship init fish | source
    end
end
