# vsecret: commands, the secrets in labv2/production and their keys (both read from Vault, so
# they need a token; nothing is offered without one). As bash's in bashrc/35-completions.

# The arguments typed so far, without the options (or --generate's number).
function __vsecret_words
    set -l skip 0
    for word in (commandline -opc)[2..-1]
        if test $skip -eq 1
            set skip 0
            continue
        end
        switch $word
            case --generate -g
                set skip 1
            case '-*'
            case '*'
                echo $word
        end
    end
end

function __vsecret_paths
    vault kv list -format=json -mount=labv2 production 2>/dev/null | jq -r '.[]' 2>/dev/null
end

# The secret's keys, less the ones already given.
function __vsecret_keys
    set -l words (__vsecret_words)
    set -l path $words[2]
    string match -q '*/*' -- $path; or set path production/$path
    set -l given (string replace -r '=.*' '' -- $words[3..-1])
    for key in (vault kv get -format=json -mount=labv2 $path 2>/dev/null | jq -r '.data.data | keys[]' 2>/dev/null)
        contains -- $key $given; or echo $key
    end
end

function __vsecret_at
    # True when $argv[1] arguments have been typed and the command is one of $argv[2..].
    set -l words (__vsecret_words)
    test (count $words) -eq $argv[1]; and contains -- $words[1] $argv[2..-1]
end

complete -c vsecret --no-files
complete -c vsecret -n 'test (count (__vsecret_words)) -eq 0' -a 'ls get set unset edit help'
complete -c vsecret -n '__vsecret_at 1 ls get set unset edit' -a '(__vsecret_paths)'
complete -c vsecret -n '__vsecret_at 2 get' -a '(__vsecret_keys)'
complete -c vsecret -n 'set -l w (__vsecret_words); test (count $w) -ge 2; and contains -- $w[1] set unset' -a '(__vsecret_keys)'
complete -c vsecret -n '__fish_seen_subcommand_from get' -l show -d 'Show the values'
complete -c vsecret -n '__fish_seen_subcommand_from set' -s g -l generate -x -d 'Generate N letters and digits'
complete -c vsecret -n '__fish_seen_subcommand_from set unset edit' -l no-sync -d "Don't force-sync the ExternalSecrets"
