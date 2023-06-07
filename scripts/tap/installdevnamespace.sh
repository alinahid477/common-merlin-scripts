#!/bin/bash


export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/extract-and-take-input.sh
source $HOME/binaries/scripts/select-from-available-options.sh
source $HOME/binaries/scripts/create-secrets.sh

createDevNS () {
    export $(cat $HOME/.env | xargs)

    local bluecolor=$(tput setaf 4)
    local normalcolor=$(tput sgr0)
    local tapvaluesfile=$1
    local confirmed=''

    printf "\nCreating Developer Namespace for TAP....\n\n"
    sleep 7

    if [[ -z $tapvaluesfile ]]
    then
        if [[ -n $TAP_PROFILE_FILE_NAME ]] 
        then
            printf "\nSetting tapvaluesfile from .env file TAP_PROFILE_FILE_NAME=$TAP_PROFILE_FILE_NAME\n"
            tapvaluesfile=$TAP_PROFILE_FILE_NAME
        else
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                while [[ -z $tapvaluesfile ]]; do
                    printf "\nHINT: requires full path of the tap values file. (eg: $HOME/configs/tap-profile-my.yaml)\n"
                    read -p "full path of the tap values file: " tapvaluesfile
                    if [[ -z $tapvaluesfile || ! -f $tapvaluesfile ]]
                    then
                        printf "empty or invalid value is not allowed.\n"
                    fi
                done        
            else
                printf "Invalid profile file found OR profile file is missing. Installation failed @ creating developer-namespace...\n"
                returnOrexit || return 1
            fi
        fi
    fi

    printf "\nSet Tap Values File: $tapvaluesfile\n"
    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        while true; do
            read -p "confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
    else
        confirmed='y'
    fi

    if [[ $confirmed == 'n' ]]
    then
        returnOrexit || return 1
    fi

    local namespacename=''
    if [[ -n $SILENTMODE && $SILENTMODE == 'YES' ]]
    then
        namespacename=$DEVELOPER_NAMESPACE_NAME
    fi

    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        while [[ -z $namespacename ]]; do
            read -p "name of the namespace: " namespacename
            if [[ -z $namespacename && ! $namespacename =~ ^[A-Za-z0-9_\-]+$ ]]
            then
                printf "empty or invalid value is not allowed.\n"
            fi
        done
    fi

    if [[ -z $namespacename ]]
    then
        printf "empty or invalid Developer Namespace name is not allowed. Setup will terminate...\n"
        returnOrexit || return 1
    else
        printf "Developer Namespace name: $namespacename\n"
    fi

    printf "\nChecking if namcespace exists in the cluster....\n"
    local isexistns=$(kubectl get ns | grep "^$namespacename")
    if [[ -n $isexistns ]] 
    then
        printf "namespace: $namespacename already exists....Skipping Create New\n"
    else
        printf "namespace: $namespacename does not exist, Creating New...."
        kubectl create ns $namespacename && printf "OK" || printf "FAILED"
        printf "\n"

        local isexistns2=$(kubectl get ns | grep "^$namespacename")
        if [[ -z $isexistns2 ]]
        then
            printf "ERROR: Failed to create namespace: $namespacename\n"
            returnOrexit || return 1
        fi
    fi
    
    printf "\nTAP Values file: $tapvaluesfile\n"
    local selectedSupplyChainType=''
    if [[ -n $tapvaluesfile ]]
    then
        printf "\nchecking for gitops presence..."
        sleep 1
        local isexistcat=$(cat $tapvaluesfile | grep -w 'gitops:$')
        if [[ -n $isexistcat ]]
        then
            selectedSupplyChainType='gitops'
            printf "FOUND\n"
        else
            printf "NOT FOUND\n"
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                local supplyChainTypes=("local_iteration" "local_iteration_with_code_from_git" "gitops")
                selectFromAvailableOptions ${supplyChainTypes[@]}
                ret=$?
                if [[ $ret == 255 ]]
                then
                    printf "${redcolor}No selection were made. Installation failed @ crating developer-namespace.${normalcolor}\n"
                    returnOrexit || return 1
                else
                    # selected option
                    selectedSupplyChainType=${supplyChainTypes[$ret]}
                fi
            else
                selectedSupplyChainType='gitops'
            fi
        fi
    fi
    
    if [[ -z $selectedSupplyChainType ]]
    then
        printf "${redcolor}No selection were made. Installation failed @ crating developer-namespace.${normalcolor}\n"
        returnOrexit || return 1
    fi
    printf "\nselected supply chain type: $selectedSupplyChainType\n"
    if [[ $selectedSupplyChainType != 'local_iteration' ]]
    then
        confirmed='y'
        if [[ $confirmed == 'y' ]]
        then
            printf "\nconfirmed...\n"
            sleep 1
            if [[ $selectedSupplyChainType == 'gitops' || $selectedSupplyChainType == 'local_iteration_with_code_from_git' ]]
            then
                # export GIT_SERVER_HOST=$gitprovidername
                # export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.git-ops/identity | base64 -w 0)
                # export GIT_SSH_PUBLIC_KEY=$(cat $HOME/.git-ops/identity.pub | base64 -w 0)
                # export GIT_SERVER_HOST_FILE=$(cat $HOME/.git-ops/known_hosts | base64 -w 0)
                printf "\nsupply chain type: $selectedSupplyChainType\n"
                confirmed=''
                if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
                then
                    printf "\nCreating ssh secret for git repo access (both private source and gitops repo)...\n"
                    while true; do
                        read -p "confirm to continue? [y/n] " yn
                        case $yn in
                            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                            * ) echo "Please answer y or n.";
                        esac
                    done
                else
                    confirmed='y'
                fi
                if [[ $confirmed == 'y' ]]
                then
                    # cp $HOME/binaries/templates/tap-git-secret.yaml /tmp/tap-git-secret.yaml
                    # extractVariableAndTakeInput /tmp/tap-git-secret.yaml
                    printf "\ncreating k8s secret for git...\n"
                    
                    export $(cat $HOME/.env | xargs)
                    sleep 1
                    # printf "\nApplying kubectl for new secret for private git repository access..."
                    # kubectl apply -f /tmp/tap-git-secret.yaml --namespace $namespacename && printf "OK" || printf "FAILED"
                    # printf "\n\n\n"
                    # sleep 3
                    if [[ -n $GIT_USERNAME && -n $GIT_PASSWORD ]]
                    then
                        printf "\ncreating k8s basic secret for git. name: $GITOPS_SECRET_NAME...\n"
                        createBasicAuthSecret $HOME/configs $namespacename
                    else
                        printf "\ncreating k8s ssh secret for git. name: $GITOPS_SECRET_NAME...\n"
                        createGitSSHSecret $namespacename
                    fi
                    sleep 1
                    printf "\nSecret for Git...COMPLETE\n"
                    sleep 2
                    # unset GIT_SERVER_HOST
                    # unset GIT_SSH_PRIVATE_KEY
                    # unset GIT_SSH_PUBLIC_KEY
                    # unset GIT_SERVER_HOST_FILE
                fi
            fi
        fi
    fi

    
    printf "\nCreating k8s secret for pvt registry access...\n"
    sleep 1
    confirmed=''
    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        while true; do
            read -p "confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
    else
        if [[ -z  $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME ]]
        then
            printf "${bluecolor}PVT_PROJECT_REGISTRY_CREDENTIALS_NAME not found.\n\r${normalcolor}"
            returnOrexit || return 1
        fi
        confirmed='y'
    fi
    if [[ $confirmed == 'y' ]]
    then
        printf "\ncreating k8s secret for registry, name: $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME ...\n"
        sleep 1
        local tmpCmdFile=/tmp/devnamespacecrscmd.tmp
        local cmdTemplate="tanzu secret registry add <PVT_PROJECT_REGISTRY_CREDENTIALS_NAME> --server <PVT_PROJECT_REGISTRY_SERVER> --username <PVT_PROJECT_REGISTRY_USERNAME> --password <PVT_PROJECT_REGISTRY_PASSWORD> --yes --namespace ${namespacename}"

        echo $cmdTemplate > $tmpCmdFile
        sleep 5
        extractVariableAndTakeInput $tmpCmdFile || true
        sleep 1
        cmdTemplate=$(cat $tmpCmdFile)
        printf "\ncreating k8s secret..."
        sleep 1
        $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
        printf "OK\n"
        rm $tmpCmdFile || true
        sleep 1
        printf "\ncreated k8s secret: $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME ...COMPLETE\n"
        sleep 1
    fi

    
    

    printf "\nGenerating RBAC for TAP leveraging SA: default..."
    sleep 1
    confirmed=''
    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        while true; do
            read -p "confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
    else
        if [[ -z $GITOPS_SECRET_NAME ]]
        then
            printf "\nReloading environment variables..."
            export $(cat $HOME/.env | xargs)
            sleep 2
        fi
        confirmed='y'
    fi
    if [[ $confirmed == 'y' ]]
    then
        cp $HOME/binaries/templates/workload-ns-setup.yaml /tmp/workload-ns-setup-$namespacename.yaml
        sleep 1
        extractVariableAndTakeInput /tmp/workload-ns-setup-$namespacename.yaml && echo "completed" || true
        sleep 1
        printf "\n"
        printf "\nCreating RBAC, RoleBinding and associating SA:default with it along with registry and repo credentials..."
        kubectl apply -n $namespacename -f /tmp/workload-ns-setup-$namespacename.yaml && printf "OK" || printf "FAILED"
        sleep 2
        printf "\n"
    fi

    local isexisttvf=$(cat $tapvaluesfile | grep -w 'scanning:$')
    if [[ -n $isexisttvf ]]
    then
        confirmed='n'
        printf "\nDetected user input for scanning functionlity. A 'kind: ScanPolicy' needs to be present in the namespace.\n"
        sleep 1
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            while true; do
                read -p "Would you create scan policy using $HOME/binaries/templates/tap-scan-policy.yaml file? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer y or n.";
                esac
            done
        else
            confirmed='y'
        fi
        if [[ $confirmed == 'y' ]]
        then
            printf "\nApplying scan policy as per $HOME/binaries/templates/tap-scan-policy.yaml.\nThis is pre-configured for java app and only detects critical level severity. Please change accordingly.\n"
            kubectl apply -f $HOME/binaries/templates/tap-scan-policy.yaml -n $namespacename
            sleep 2
            printf "\nScan policy creation ... COMPLETE\n"
        fi
    fi
    
    printf "\nChecking whether it requires tekton pipeline for testing...."
    local isexisttvf2=$(cat $tapvaluesfile | grep -i 'supply_chain: testing')
    sleep 1
    if [[ -n $isexisttvf2 ]]
    then
        printf "Yes.\nSupply Chain detected with testing functionlity. Applying a maven test tekton pipeline based on file $HOME/binaries/templates/tap-maven-test-tekton-pipeline.yaml...\n"
        confirmed='n'
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            while true; do
                read -p "Would you create maven-test-tekton-pipeline? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer y or n.";
                esac
            done
        else
            confirmed='y'
        fi
        if [[ $confirmed == 'y' ]]
        then
            printf "\nCreating pipeline..\n"
            kubectl apply -f $HOME/binaries/templates/tap-maven-test-tekton-pipeline.yaml -n $namespacename
            sleep 2
        fi
    else
        printf "NO.\nNo supply chain detected with testing functionlity."
    fi
    echo $namespacename >> $HOME/configs/PROVISIONEDDEVNS || true
    printf "\n\n**** Developer namespace: $namespacename setup...COMPLETE\n\n\n"
    sleep 2
}
