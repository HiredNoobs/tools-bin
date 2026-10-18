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

complete -c redis --no-files
complete -c redis -n 'test (count (commandline -opc)) -eq 1' -l pod -x -d 'Run in this pod' \
    -a '(kubectl get pods -n redis -l app.kubernetes.io/name=redis -o name 2>/dev/null | string replace pod/ "")'
complete -c redis -n 'test (count (commandline -opc)) -eq 2; and test (commandline -opc)[2] = --pod' \
    -a '(kubectl get pods -n redis -l app.kubernetes.io/name=redis -o name 2>/dev/null | string replace pod/ "")'
complete -c redis -n 'test (__redis_nargs) -eq 0; and not test (commandline -opc)[-1] = --pod' \
    -a 'scan-delete sentinel help ACL INFO ROLE DBSIZE SCAN KEYS TYPE TTL GET DEL CLIENT CONFIG MEMORY SLOWLOG MONITOR'
complete -c redis -n 'contains -- (__redis_args)[1] ACL acl; and test (__redis_nargs) -eq 1' -a 'LIST USERS WHOAMI GETUSER CAT LOG'
complete -c redis -n 'test (__redis_args)[1] = sentinel; and test (__redis_nargs) -eq 1' -a 'SENTINEL INFO ROLE PING'
complete -c redis -n 'test (__redis_args)[1] = sentinel; and contains -- (__redis_args)[2] SENTINEL sentinel; and test (__redis_nargs) -eq 2' \
    -a 'get-master-addr-by-name master masters replicas sentinels ckquorum failover reset'
complete -c redis -n 'test (__redis_args)[1] = scan-delete' -l db -x -d 'Database number'
complete -c redis -n 'test (__redis_args)[1] = scan-delete' -l yes -d "Don't ask first"
