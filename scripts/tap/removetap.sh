#!/bin/bash

printf "\n\nStarting remove TAP...\n\n"
printf "\nRemoving tap from tap-install...\n"
tanzu package installed delete tap --namespace tap-install --yes || (echo "ERROR: Failed to delete installed tap from ns: tap-install" && true)


printf "\nRemoving package repository...\n"
tanzu package repository delete tanzu-tap-repository --namespace tap-install --yes || (echo "ERROR: Failed to delete repository: tanzu-tap-repository from ns: tap-install" && exit 1)

if [[ -f $HOME/configs/output ]]
then
    printf "\nRemoving merlin output file...\n"
    rm $HOME/configs/output || (echo "ERROR: Failed to delete merlin output file" && exit 1)
fi

printf "\nTAP Remove...COMPLETE.\n\n\n"