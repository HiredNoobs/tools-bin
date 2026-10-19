# deployment: its commands, read from the script (its command_* functions), then the context's
# namespaces for status. As bash's in bashrc/35-completions.
function __deployment_commands
    test -f $TOOLS_BIN/deployment; or return
    string replace -rf '^function command_([a-z_]+) .*' '$1' <$TOOLS_BIN/deployment
end

complete -c deployment --no-files
complete -c deployment -n 'test (count (commandline -opc)) -eq 1' -a '(__deployment_commands)'
complete -c deployment -n '__fish_seen_subcommand_from status; and test (count (commandline -opc)) -eq 2' -a '(kubectl get namespaces -o name 2>/dev/null | string replace namespace/ "")'
