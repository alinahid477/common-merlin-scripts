#!/bin/bash

returned='n'
function returnOrexit()
{


    if [[ $1 == "kill shuttle" || $SSHUTTLE == true ]]
    then
        echo '=> Terminating sshuttle process by signal (SIGINT, SIGTERM, SIGKILL, EXIT)'
        killall -9 sshuttle ssh
        iptables --flush
        sleep 2
        iptables --flush
        sleep 1
        echo "=> *DONE*"
        unset SSHUTTLE
    fi

    returned='n'
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        returned='y'
        return 1 # very important. return 1 means error. return 0 means success.
    else
        exit
    fi
}