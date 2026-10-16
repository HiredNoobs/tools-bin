# rabbitmq: rabbitmqctl's common commands, diag (rabbitmq-diagnostics) and plugins. As bash's in
# bashrc/35-completions.
complete -c rabbitmq --no-files
complete -c rabbitmq -n '__fish_use_subcommand' -a 'diag plugins help status cluster_status environment list_queues list_connections list_channels list_consumers list_exchanges list_bindings list_users list_vhosts list_permissions'
complete -c rabbitmq -n '__fish_seen_subcommand_from diag; and test (count (commandline -opc)) -eq 2' -a 'status ping check_running check_local_alarms check_port_connectivity memory_breakdown listeners log_tail'
complete -c rabbitmq -n '__fish_seen_subcommand_from plugins; and test (count (commandline -opc)) -eq 2' -a 'list enable disable'
