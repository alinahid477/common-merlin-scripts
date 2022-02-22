#!/bin/bash
export $(cat /root/.env | xargs)
returned='n'
returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        returned='y'
        return
    else
        exit
    fi
}







if [[ $returned == 'y' ]]
then
    returnOrexit
fi



if [[ $returned == 'y' ]]
then
    returnOrexit
fi


if [[ $COMPLETE == 'YES' && $returned == 'n' ]]
then
    isloggedin='n'
    printf "\nFound marked as complete.\nChecking tanzu config...\n"
    sleep 1
    tanzucontext=$(tanzu config server list -o json | jq '.[].context' | xargs)
    if [[ -n $tanzucontext ]]
    then
        tanzuname=$(tanzu config server list -o json | jq '.[].name' | xargs)
        if [[ -n $tanzuname ]]
        then
            tanzupath=$(tanzu config server list -o json | jq '.[].path' | xargs)
            tanzuendpoint=$(tanzu config server list -o json | jq '.[].endpoint' | xargs)
            if [[ -n $tanzupath ]]
            then
                bastion_host_tunnel $tanzupath
                printf "\nFound \n\tcontext: $tanzucontext \n\tname: $tanzuname \n\tpath: $tanzupath\n"
                # sleep 1
                # tanzu login --kubeconfig $tanzupath --context $tanzucontext --name $tanzuname
                isloggedin='y'
            fi
            if [[ -n $tanzuendpoint ]]
            then
                printf "\nFound \n\tcontext: $tanzucontext \n\tname: $tanzuname \n\tendpoint: $tanzuendpoint\nPerforming Tanzu login...\n"
                sleep 1
                tanzu login --endpoint $tanzuendpoint --context $tanzucontext --name $tanzuname
                isloggedin='y'
            fi
        fi
    fi

    if [[ $isloggedin == 'n' ]]
    then
        printf "\nTanzu context does not exist. Creating new one...\n"
        sleep 1
        if [[ -z $AUTH_ENPOINT ]]
        then
            printf "\nNO AUTH_ENDPOINT given.\nLooking for kubeconfig in ~/.kube-tkg/config...\n"
            sleep 1
            kubeconfigfile=/root/.kube-tkg/config
            isexist=$(ls $kubeconfigfile)
            if [[ -z $isexist ]]
            then
                printf "\nERROR: kubeconfig not found in $kubeconfigfile\nExiting...\n"
                returnOrexit
            fi
            filename=$(ls -1tc ~/.config/tanzu/tkg/clusterconfigs/ | head -1)
            if [[ -z $filename ]]
            then
                printf "\nERROR: Management cluster config file not found in ~/.config/tanzu/tkg/clusterconfigs/. Exiting...\n"
                returnOrexit
            fi
            clustername=$(cat ~/.config/tanzu/tkg/clusterconfigs/$filename | awk -F: '$1=="CLUSTER_NAME"{print $2}' | xargs)
            if [[ -z $clustername ]]
            then
                printf "\nERROR: CLUSTER_NAME could not be extracted. Please check file ~/.config/tanzu/tkg/clusterconfigs/$filename. Exiting...\n"
                returnOrexit
            fi            
            contextname=$(parse_yaml $kubeconfigfile | grep "\@$clustername" | awk -F= '$1=="contexts_name"{print $2}' | xargs)    
            printf "\nfound \n\tCLUSTER_NAME: $clustername\n\tCONTEXT_NAME: $contextname\n"
            sleep 1
            bastion_host_tunnel $kubeconfigfile
            printf "\ntanzu login --kubeconfig $kubeconfigfile --context $contextname --name $clustername ...\n"
            tanzu login --kubeconfig $kubeconfigfile --context $contextname --name $clustername
        else
            printf "\ntanzu login --endpoint $AUTH_ENDPOINT --name $clustername ...\n"
            tanzu login --endpoint $AUTH_ENDPOINT --name $clustername
        fi
    fi
    printf "\ntanzu connected to below ...\n"
    sleep 1
    tanzu cluster list --include-management-cluster

    printf "\nIs this correct? ...\n"
    sleep 1
    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; echo "TANZU_CONNECT=YES" >> /tmp/TANZU_CONNECT; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done  
fi