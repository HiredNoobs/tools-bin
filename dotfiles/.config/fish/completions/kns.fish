complete -c kns --no-files --arguments '(kubectl get namespaces -o name 2>/dev/null | string replace namespace/ "")' --condition 'test (count (commandline -opc)) -eq 1'
