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

printf "\nkubeconfig merging..."
test -f $HOME/.kube/config-merlin-merge.bak && rm $HOME/.kube/config-merlin-merge.bak
cp $HOME/.kube/config $HOME/.kube/config-merlin-merge.bak && KUBECONFIG=$HOME/.kube/config:$newkubeconfig kubectl config view --flatten > /tmp/kubeconfig && mv /tmp/kubeconfig $HOME/.kube/config
printf "COMPLETE\n"