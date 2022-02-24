#!/bin/bash
export $(cat /root/.env | xargs)

source $HOME/binaries/scripts/bastion_host_util.sh

source $HOME/binaries/scripts/select-from-available-options.sh
source $HOME/binaries/scripts/parse_yaml.sh

function tanzu_connect () {

    isloggedin='n'
    printf "\nChecking tanzu config...\n"
    sleep 1
    unset tanzuname
    readarray -t tanzunames < <(tanzu config server list -o json | jq -r '.[].name')
    if [[ ${#tanzunames[@]} -gt 1 ]]
    then
        # prompt user to select 1
        
        selectFromAvailableOptions ${tanzunames[@]}
        ret=$?
        if [[ $ret == 255 ]]
        then
            printf "\nERROR: Invalid option selected. Unable to connect.\n"
            returnOrexit || return 1
        else
            tanzuname=${tanzunames[$ret]}
        fi
    else    
        # only 1 context. Most likely the most usual.
        tanzuname="${contextnames[0]}"
    fi
    
    if [[ -n $tanzuname ]]
    then
        tanzucontext=$(tanzu config server list -o json | jq -r '.[] | select(.name=="'$tanzuname'") | .context')
        tanzupath=$(tanzu config server list -o json | jq -r '.[] | select(.name=="'$tanzuname'") | .path')
        tanzuendpoint=$(tanzu config server list -o json | jq -r '.[] | select(.name=="'$tanzuname'") | .endpoint')
        if [[ -n $tanzupath ]]
        then
            if [[ -n $BASTION_HOST ]]
            then
                create_bastion_tunnel_auto_tkg $tanzupath || returnOrexit || return 1
            fi
            
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

    if [[ $isloggedin == 'n' ]]
    then
        printf "\nTanzu context does not exist. Creating new one...\n"
        sleep 1
        if [[ -z $AUTH_ENPOINT ]]
        then
            kubeconfigfile=$HOME/.kube-tkg/config
            printf "\nNO AUTH_ENDPOINT given.\nLooking for kubeconfig in $kubeconfigfile...\n"
            sleep 1
            isexist=$(ls $kubeconfigfile)
            if [[ -z $isexist ]]
            then
                printf "\nERROR: kubeconfig not found in $kubeconfigfile\nExiting...\n"
                returnOrexit || return 1
            fi
            filename=$(ls -1tc $HOME/.config/tanzu/tkg/clusterconfigs/ | head -1)
            if [[ -z $filename ]]
            then
                printf "\nERROR: Management cluster config file not found in $HOME/.config/tanzu/tkg/clusterconfigs/. Exiting...\n"
                returnOrexit || return 1
            fi
            clustername=$(cat $HOME/.config/tanzu/tkg/clusterconfigs/$filename | awk -F: '$1=="CLUSTER_NAME"{print $2}' | xargs)
            if [[ -z $clustername ]]
            then
                printf "\nERROR: CLUSTER_NAME could not be extracted. Please check file ~/.config/tanzu/tkg/clusterconfigs/$filename. Exiting...\n"
                returnOrexit || return 1
            fi            
            contextname=$(parse_yaml $kubeconfigfile | grep "\@$clustername" | awk -F= '$1=="contexts_name"{print $2}' | xargs)    
            printf "\nfound \n\tCLUSTER_NAME: $clustername\n\tCONTEXT_NAME: $contextname\n"
            sleep 1

            if [[ -n $BASTION_HOST ]]
            then
                create_bastion_tunnel_from_kubeconfig $kubeconfigfile || returnOrexit || return 1
            fi
            
            printf "\ntanzu login --kubeconfig $kubeconfigfile --context $contextname --name $clustername ...\n"
            tanzu login --kubeconfig $kubeconfigfile --context $contextname --name $clustername || returnOrexit || return 1
            isloggedin='y'
        else
            printf "\ntanzu login --endpoint $AUTH_ENDPOINT --name $clustername ...\n"
            tanzu login --endpoint $AUTH_ENDPOINT --name $clustername  || returnOrexit || return 1
            isloggedin='y'
        fi
    fi

    if [[ $isloggedin == 'y' ]]
    then
        return 0
    fi
}

function tanzu_connect_and_confirm () {

    tanzu_connect || returnOrexit || return 1

    printf "\ntanzu connected to below ...\n"
    sleep 1
    tanzu cluster list --include-management-cluster

    printf "\nIs this correct? ...\n"
    sleep 1
    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; echo "TANZU_CONNECT=YES" >> /tmp/TANZU_CONNECT; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; returnOrexit || return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}