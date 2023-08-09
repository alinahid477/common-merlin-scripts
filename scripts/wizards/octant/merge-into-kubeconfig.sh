#!/bin/bash

newkubeconfig=$1

if [[ -z $newkubeconfig ]]
then
    printf "\nERROR: New kubeconfig file path not supplied as paramater\n"
    printf "Usage: merge-into-kubeconfig.sh /path/to/new/config\n"
    exit 1
fi

if [[ ! -f $newkubeconfig ]]
then
    printf "\nERROR: New kubeconfig file could not be found.{$newkubeconfig}\n"
    printf "Usage: merge-into-kubeconfig.sh /path/to/new/config\n"
    exit 1
fi

rm $HOME/.kube/config.bak
cp $HOME/.kube/config $HOME/.kube/config.bak && KUBECONFIG=$HOME/.kube/config:$newkubeconfig kubectl config view --flatten > /tmp/kubeconfig && mv /tmp/kubeconfig $HOME/.kube/config && rm $newkubeconfig