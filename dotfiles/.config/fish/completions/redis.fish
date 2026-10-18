# redis: its own commands and the common Redis ones. As bash's in bashrc/35-completions.

# The words after redis and a leading --pod <pod>.
function __redis_args
    set -l args (commandline -opc)[2..-1]
    if test "$args[1]" = --pod
        set args $args[3..-1]
    end
    printf '%s\n' $args
end

function __redis_nargs
    count (__redis_args)
end

# The command line is SENTINEL (any case) with $argv[1] words after it.
function __redis_sentinel_at
    set -l args (__redis_args)
    test (count $args) -eq (math $argv[1] + 1); and test (string upper -- "$args[1]") = SENTINEL
end

complete -c redis --no-files
complete -c redis -n 'test (count (commandline -opc)) -eq 1' -l pod -x -d 'Run in this pod' \
    -a '(kubectl get pods -n redis -l app.kubernetes.io/name=redis -o name 2>/dev/null | string replace pod/ "")'
complete -c redis -n 'test (count (commandline -opc)) -eq 2; and test (commandline -opc)[2] = --pod' \
    -a '(kubectl get pods -n redis -l app.kubernetes.io/name=redis -o name 2>/dev/null | string replace pod/ "")'
complete -c redis -n 'test (__redis_nargs) -eq 0; and not test (commandline -opc)[-1] = --pod' \
    -a 'scan-delete sentinel help ACL INFO ROLE DBSIZE SCAN KEYS TYPE TTL GET DEL CLIENT CONFIG MEMORY SLOWLOG MONITOR SENTINEL'
complete -c redis -n 'contains -- (__redis_args)[1] ACL acl; and test (__redis_nargs) -eq 1' -a 'LIST USERS WHOAMI GETUSER CAT LOG'
# SENTINEL's subcommands, then the master's name (redis) for those that take one.
complete -c redis -n '__redis_sentinel_at 0' \
    -a 'MASTERS MASTER REPLICAS SENTINELS GET-MASTER-ADDR-BY-NAME CKQUORUM FAILOVER RESET MYID INFO-CACHE CONFIG SET REMOVE MONITOR FLUSHCONFIG PENDING-SCRIPTS SIMULATE-FAILURE IS-MASTER-DOWN-BY-ADDR DEBUG'
complete -c redis -n '__redis_sentinel_at 1; and contains -- (string upper -- (__redis_args)[2]) MASTER REPLICAS SLAVES SENTINELS GET-MASTER-ADDR-BY-NAME CKQUORUM FAILOVER RESET INFO-CACHE SET REMOVE' -a 'redis'
complete -c redis -n '__redis_sentinel_at 1; and test (string upper -- (__redis_args)[2]) = CONFIG' -a 'GET SET'
complete -c redis -n 'test (__redis_args)[1] = scan-delete' -l db -x -d 'Database number'
complete -c redis -n 'test (__redis_args)[1] = scan-delete' -l yes -d "Don't ask first"
