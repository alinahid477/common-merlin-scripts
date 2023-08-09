#!/bin/bash

clustername=$1

if [[ -z $clustername ]]
then
    printf "\nERROR: no cluster name supplied as paramater\n"
    printf "Usage: remove-from-kubeconfig.sh /path/to/new/config\n"
    exit 1
fi

kubectl config unset users.$clustername

kubectl config unset contexts.$clustername

kubectl config unset clusters.$clustername