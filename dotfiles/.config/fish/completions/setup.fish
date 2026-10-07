# setup: its commands, read from the script (its command_* functions). As bash's in
# bashrc/35-completions.
function __setup_commands
    test -f $TOOLS_BIN/setup; or return
    string replace -rf '^function command_([a-z_]+) .*' '$1' <$TOOLS_BIN/setup
end

complete -c setup --no-files
complete -c setup -n 'test (count (commandline -opc)) -eq 1' -a '(__setup_commands)'
