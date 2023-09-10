#!/bin/bash

test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

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



printf "\nTAP delete summary:\n --removed package tap from ns: tap-install\n --removed package repository tanzu-tap-repository from ns: tap-install.\n"
printf "\nPlease delete the below user purpose secrets manually:\n"
printf " - $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME from ns: tap-install\n   cmd: tanzu secret registry delete $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME -n tap-install\n"
printf " - $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME from ns: $DEVELOPER_NAMESPACE_NAME\n   cmd: tanzu secret registry delete $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME -n $DEVELOPER_NAMESPACE_NAME\n"
printf " - tap-registry from ns: tap-install\n   cmd: tanzu secret registry delete tap-registry -n tap-install\n"
printf " - $GITOPS_SECRET_NAME from ns: tap-install\n   cmd: kubectl delete secret $GITOPS_SECRET_NAME -n tap-install\n"
printf " - $GITOPS_SECRET_NAME from ns: $DEVELOPER_NAMESPACE_NAME\n   cmd: kubectl delete secret $GITOPS_SECRET_NAME -n $DEVELOPER_NAMESPACE_NAME\n"

printf "\nall secret delete commands below(for copy paste convenience):\n"
printf "tanzu secret registry delete $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME -n tap-install\n"
printf "tanzu secret registry delete $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME -n $DEVELOPER_NAMESPACE_NAME\n"
printf "tanzu secret registry delete tap-registry -n tap-install\n"
printf "kubectl delete secret $GITOPS_SECRET_NAME -n tap-install\n"
printf "kubectl delete secret $GITOPS_SECRET_NAME -n $DEVELOPER_NAMESPACE_NAME\n"
printf "\n"
sleep 5
