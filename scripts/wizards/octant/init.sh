#!/bin/bash
test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true


test -f $HOME/.ssh/id_rsa && chmod 600 $HOME/.ssh/id_rsa

printf "\n\n\n***********Starting octant init...*************\n"

if [[ -n $BASTION_HOST ]]
then
    printf "\nBastion host specified..Establishing tunnels...\n"
    if [[ ! -f $HOME/.ssh/id_rsa ]]
    then
        printf "\n\nERROR: Bastion host specified. BUT no id_rsa file supplied.\nYou must place a id_rsa file in .ssh dir.Exit....\n\n"
    fi
    ssh-keyscan $BASTION_HOST > /root/.ssh/known_hosts

    if [[ -n $BASTION_TUNNELS && $BASTION_TUNNELS == *[,]* ]]
    then
        printf "\nMultiple bastion tunnels specified\n\n"
        tunnelstr=""
        tunnels=$(echo $BASTION_TUNNELS | tr "," "\n")
        for tunnel in $tunnels
        do
            tunnelstr=$(echo "$tunnelstr -L $tunnel")
        done
        printf "\nssh -i /root/.ssh/id_rsa -4 -fNT $tunnelstr $BASTION_USERNAME@$BASTION_HOST\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT $tunnelstr $BASTION_USERNAME@$BASTION_HOST
    else
        printf "\nSingle bastion tunnel specified\n\n"
        printf "\nssh -i /root/.ssh/id_rsa -4 -fNT -L $BASTION_TUNNELS $BASTION_USERNAME@$BASTION_HOST\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L $BASTION_TUNNELS $BASTION_USERNAME@$BASTION_HOST
    fi

    if [[ -n $TKG_SUPERVISOR_ENDPOINT ]]
    then
        printf "\nEstablishing tunnel for login on 443 for $TKG_SUPERVISOR_ENDPOINT through $BASTION_USERNAME@$BASTION_HOST...\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
    fi

    printf "\nTunneling...COMPLETE\n"
fi



printf "\n\n\nRUN merlin --help for details on how to use this UI\n"

cd ~


/bin/bash