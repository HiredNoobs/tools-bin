# redis: its own commands and the common Redis ones. As bash's in bashrc/35-completions.
complete -c redis --no-files
complete -c redis -n '__fish_use_subcommand' -a 'scan-delete help ACL INFO DBSIZE SCAN KEYS TYPE TTL GET DEL CLIENT CONFIG MEMORY SLOWLOG MONITOR'
complete -c redis -n '__fish_seen_subcommand_from ACL acl; and test (count (commandline -opc)) -eq 2' -a 'LIST USERS WHOAMI GETUSER CAT LOG'
complete -c redis -n '__fish_seen_subcommand_from scan-delete' -l db -x -d 'Database number'
complete -c redis -n '__fish_seen_subcommand_from scan-delete' -l yes -d "Don't ask first"
