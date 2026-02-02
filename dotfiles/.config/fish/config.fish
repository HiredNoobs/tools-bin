if status is-interactive
    # Remove greeting
    set fish_greeting

    # Use starship
    starship init fish | source

    # Update PATH
    fish_add_path ~/tools-bin/bin

    # Env vars (-x = export)
    set -x SHELL $(which fish)  # For tmux

    # Aliases
    alias "tm" "tmux new-session \; split-window -h -p 50 \; select-pane -L \; attach"
end
