#!/bin/bash

function deployTKC() {
    printf "\n\n\n"
    printf "*********************************************\n"
    printf "*** starting tkg k8s cluster provision...****\n"
    printf "*********************************************\n"
    printf "\n\n\n"

    sed -i '$ d' $configfile

    printf "Checking if resource group with name $AZURE_RESOURCE_GROUP exists...\n"
    isexistsAndLocation=$(az group show --name $AZURE_RESOURCE_GROUP | jq .location | xargs)
    if [[ -z $isexistsAndLocation ]]
    then
        printf "Resource group does not exist. Creating new...\n"
        az group create -l $AZURE_LOCATION -n $AZURE_RESOURCE_GROUP --tags tkg $CLUSTER_NAME
        printf "DONE\n\n"
    else
        if [[ "$isexistsAndLocation" == "$AZURE_LOCATION" ]]
        then
            printf "Resource group with name $AZURE_RESOURCE_GROUP already exists. No need to create new.\n"
            while true; do
                read -p "Confirm to continue using existing RG $AZURE_RESOURCE_GROUP? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                    [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        else
            printf "Resource group with name $AZURE_RESOURCE_GROUP already exists in location $isexistsAndLocation.\n"
            printf "HOWEVER, selected azure location is: $AZURE_LOCATION.\n"
            printf "ERROR: Resource group location and cluster resources location cannot be different. Cannot complete process. Existing...\n"
            exit
        fi
        
    fi


    printf "Accepting vm image azure sku $TKG_PLAN...\n\n"
    az vm image terms accept --publisher vmware-inc --offer tkg-capi --plan $TKG_PLAN --subscription $AZ_SUBSCRIPTION_ID
    printf "\n\nDONE.\n\n\n"


    printf "Creating NSG in azure...\n\n"
    az network nsg create -g $AZURE_RESOURCE_GROUP -n $AZ_NSG_NAME --tags tkg $CLUSTER_NAME
    printf "\n\nDONE.\n\n\n"


    printf "Extracting latest TKR version....\n\n"
    tanzucontext=$(tanzu config server list -o json | jq '.[].context' | xargs)
    printf "Tanzu Context: $tanzucontext. Switching kubernetes context...\n"
    kubectl config use-context $tanzucontext
    printf "Performing kubectl get tkr ...\n"
    latesttkrversion=$(kubectl get tkr --sort-by=.metadata.name -o jsonpath='{.items[-1:].metadata.name}' | awk 'NR==1{print $1}')
    printf "Latest TKR: $latesttkrversion\n"

    read -p "Type in tkr value OR press enter to accept the default value: $latesttkrversion " inp
    if [[ -n $inp ]]
    then
        latesttkrversion=$inp
    fi

    printf "Creating k8s cluster from yaml called ~/workload-clusters/$CLUSTER_NAME.yaml\n\n"
    tanzu cluster create  --file $configfile -v 9 --tkr $latesttkrversion # --dry-run > ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml
    printf "\n\nDONE.\n\n\n"

    # printf "applying ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml\n\n"
    # kubectl apply -f ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml
    # printf "\n\nDONE.\n\n\n"

    printf "\nWaiting 1 mins to complete cluster create\n"
    sleep 1m
    printf "\n\nDONE.\n\n\n"

    printf "\nGetting cluster info\n"
    tanzu cluster kubeconfig get $CLUSTER_NAME --admin
    printf "\n\nDONE.\n\n\n"

    if [[ ! -z "$TMC_ATTACH_URL" ]]
    then
        printf "\nAttaching cluster to TMC\n"
        printf "\nSwitching context\n"
        kubectl config use-context $CLUSTER_NAME-admin@$CLUSTER_NAME    
        kubectl create -f $TMC_ATTACH_URL
        printf "\n\nDONE.\n\n\n"
        printf "\nWaiting 1 mins to complete cluster attach\n"
        sleep 1m
        printf "\n\nDONE.\n\n\n"
    else
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
        source $SCRIPT_DIR/attach_to_tmc.sh -g $TMC_CLUSTER_GROUP -n $CLUSTER_NAME
    fi
    
    

    printf "\n\n\n"
    printf "*******************\n"
    printf "***COMPLETE.....***\n"
    printf "*******************\n"
    printf "\n\n\n"
}