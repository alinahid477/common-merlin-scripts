#!/bin/bash

export $(cat /root/.env | xargs)

function deployTKC() {
    local configfile=$1

    if [[ -z $configfile ]]
    then
        printf "\n${redcolor}ERROR: configfile parameter is missing${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "Executing tanzu clauster create using file ${yellowcolor}$configfile.${normalcolor}....\n"
    if [[ -n $BASTION_HOST ]]
    then
        source $HOME/binaries/scripts/bastion/bastionhostworkloadsetup.sh
        auto_tkgdeploy $configfile
    else
        tanzu cluster create  --file $configfile -v 9
    fi
    

    return 0
}