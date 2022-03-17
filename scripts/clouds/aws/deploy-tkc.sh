#!/bin/bash

export $(cat $HOME/.env | xargs)

function deployTKC() {
    local configfile=$1

    if [[ -z $configfile ]]
    then
        printf "\n${redcolor}ERROR: configfile parameter is missing${normalcolor}\n"
        returnOrexit || return 1
    fi

    if [[ -z $AWS_REGION ]]
    then
        printf "\n${redcolor}ERROR: AWS_REGION missing from environment variable.${normalcolor}\n"
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