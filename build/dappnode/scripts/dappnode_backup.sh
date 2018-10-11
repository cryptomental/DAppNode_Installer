#!/bin/bash

VPN_VOLUME='dncore_vpndnpdappnodeeth_data'

save () {
    docker run -it --rm -v $VPN_VOLUME:/volume -v $PWD:/backup alpine tar -czf /backup/$1 -C /volume ./
}

restore () {
    docker run -it --rm -v $VPN_VOLUME:/volume -v $PWD:/backup alpine \
        sh -c "rm -rf /volume/* /volume/..?* /volume/.[!.]* ; tar -C /volume/ -xzf /backup/$1"
}

if  [ ! $# -eq 2 ]; then
    echo "Usage:"
    echo "dappnode_vpn_backup <save|restore> <filename>"
    exit 1
else
    if [ $1 == "save" ]; then save $2
    elif [ $1 == "restore" ]; then restore $2
    else echo "Unknown command."
    fi
fi
