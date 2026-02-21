#!/usr/bin/env bash

function confirm_dangerous {
    local confirm
    echo "This action is potentially dangerous, would you like to continue?"
    read -r -p "Type 'yes' to confirm: " confirm

    if [[ "$confirm" != "yes" ]]; then
        echo "Aborting..."
        return 1
    fi
}
