#!/bin/bash


export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/extract-and-take-input.sh
source $HOME/binaries/scripts/select-from-available-options.sh
source $HOME/binaries/scripts/create-secrets.sh

createDevNS () {
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
    local isexist=$(kubectl get ns | grep "^$namespacename")

    if [[ -n $isexist ]] 
    then
        printf "namespace: $namespacename already exists....Skipping Create New\n"
    else
        printf "namespace: $namespacename does not exist, Creating New...."
        kubectl create ns $namespacename && printf "OK" || printf "FAILED"
        printf "\n"

        isexist=$(kubectl get ns | grep "^$namespacename")
        if [[ -z $isexist ]]
        then
            printf "ERROR: Failed to create namespace: $namespacename\n"
            returnOrexit || return 1
        fi
    fi

    local selectedSupplyChainType=''
    if [[ -n $tapvaluesfile ]]
    then
        isexist=$(cat $tapvaluesfile | grep -w 'gitops:$')
        if [[ -n $isexist ]]
        then
            selectedSupplyChainType='gitops'
        else
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
    if [[ $selectedSupplyChainType != 'local_iteration' ]]
    then
        ###
        # the below commented out section is not needed now because 
        # I have not figured out yet with ootb TAP supply chain how to pass 2 different git secrets 1 for pvt-source-repo and 1 for gitops-repo.
        # if I can figure it out then will unblock the below for gitops-repo BUT
        # I will still need to figure out a way to add pvt-git-repo secret to default sa. 
        # (which I have solved for cartographer. BUT not yet for TAP. this is because TAP ootb supply chain are weird and works with static set to names which are not well documented)
        ###
        # if [[ ! -f $HOME/.git-ops/identity || ! -f $HOME/.git-ops/identity.pub ]]
        # then
        #     printf "Identity files for git repository (public and private key files) not found.\n"
        #     printf "If you already have one for git repository confirm 'n' and place the files with name identity and identity.pub in $HOME/.git-ops/ directory.\n"
        #     printf "Otherwise, confirm y to create a new one.\n"
        #     while true; do
        #         read -p "Would you like to create identity file for your git repo? [y/n] " yn
        #         case $yn in
        #             [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
        #             [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
        #             * ) echo "Please answer y or n.";
        #         esac
        #     done

        #     if [[ $confirmed == 'y' ]]
        #     then
        #         local keyemail=''
        #         while [[ -z $keyemail ]]; do
        #             read -p "Input Email or Username for generating public and private key pair for gitops: " keyemail
        #             if [[ -z $keyemail ]]
        #             then
        #                 printf "WARN: empty value not allowed.\n"
        #             fi
        #         done
        #         printf "Generating key pair..."
        #         ssh-keygen -f $HOME/.git-ops/identity -q -t rsa -b 4096 -C "$keyemail" -N ""
        #         sleep 2
        #         printf "COMPLETE\n"
        #     fi
        # else
        #     printf "Git repo identity keypair for GitOps found in $HOME/.git-ops/.\n"
        # fi

        # printf "${bluecolor}Please make sure that identity.pub exists in the gitrepo.\n"
        # printf "eg: for bitbucket it is in: https://bitbucket.org/<projectname>/<reponame>/admin/addon/admin/pipelines/ssh-keys\n"
        # printf "OR for githun it is in: https://github.com/<username>/<reponame>/settings/keys/new${normalcolor}\n"
        # sleep 2

        # printf "Here's identity.pub\n"
        # cat $HOME/.git-ops/identity.pub
        # sleep 2
        # printf "\n\n"
        # while true; do
        #     read -p "Confirm to continue to create secret in k8s cluster using the Git repo keypair? [y/n] " yn
        #     case $yn in
        #         [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
        #         [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
        #         * ) echo "Please answer y or n.";
        #     esac
        # done
        confirmed='y'
        if [[ $confirmed == 'y' ]]
        then
            # if [[ ! -f $HOME/.git-ops/known_hosts ]]
            # then
            #     printf "Hint: ${bluecolor}Gitrepo host name. eg: github.com, bitbucket.org${normalcolor}\n"

            #     local gitprovidername=''
            #     while [[ -z $gitprovidername ]]; do
            #         read -p "Input the hostname of they git repo: " gitprovidername
            #         if [[ -z $gitprovidername ]]
            #         then
            #             printf "WARN: empty value not allowed.\n"
            #         fi
            #     done

            #     printf "Creating known_hosts file for $gitprovidername..."
            #     ssh-keyscan $gitprovidername > $HOME/.git-ops/known_hosts || returnOrexit || return 1
            #     printf "COMPLETE\n"
            # fi

            # if [[ $selectedSupplyChainType == 'local_iteration_with_code_from_git' ]]
            # then
            #     local tmpCmdFile=/tmp/devnamespacecmdgitssh.tmp
            #     local cmdTemplate="kubectl create secret generic <GITOPS-SECRET-NAME> --from-file=$HOME/.git-ops/identity --from-file=$HOME/.git-ops/identity.pub --from-file=$HOME/.git-ops/known_hosts --namespace ${namespacename}"

            #     echo $cmdTemplate > $tmpCmdFile
            #     extractVariableAndTakeInput $tmpCmdFile
            #     cmdTemplate=$(cat $tmpCmdFile)

            #     export $(cat $HOME/.env | xargs)

            #     printf "\nCreating new secret for private git repository access..."
            #     $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
            #     printf "\n\n\n"
            #     sleep 4
            # fi
            if [[ $selectedSupplyChainType == 'gitops' || $selectedSupplyChainType == 'local_iteration_with_code_from_git' ]]
            then
                # export GIT_SERVER_HOST=$gitprovidername
                # export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.git-ops/identity | base64 -w 0)
                # export GIT_SSH_PUBLIC_KEY=$(cat $HOME/.git-ops/identity.pub | base64 -w 0)
                # export GIT_SERVER_HOST_FILE=$(cat $HOME/.git-ops/known_hosts | base64 -w 0)

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

                    export $(cat $HOME/.env | xargs)

                    # printf "\nApplying kubectl for new secret for private git repository access..."
                    # kubectl apply -f /tmp/tap-git-secret.yaml --namespace $namespacename && printf "OK" || printf "FAILED"
                    # printf "\n\n\n"
                    # sleep 3
                    if [[ -n $GIT_USERNAME && -n $GIT_PASSWORD ]]
                    then
                        createBasicAuthSecret $HOME/configs $namespacename
                    else
                        createGitSSHSecret $namespacename
                    fi
                    
                    

                    # unset GIT_SERVER_HOST
                    # unset GIT_SSH_PRIVATE_KEY
                    # unset GIT_SSH_PUBLIC_KEY
                    # unset GIT_SERVER_HOST_FILE
                fi
            fi
        fi
    fi

    
    printf "\nCreating registry credential for pvt registry access...\n"
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
        local tmpCmdFile=/tmp/devnamespacecmd.tmp
        local cmdTemplate="tanzu secret registry add <PVT_PROJECT_REGISTRY_CREDENTIALS_NAME> --server <PVT_PROJECT_REGISTRY_SERVER> --username <PVT_PROJECT_REGISTRY_USERNAME> --password <PVT_PROJECT_REGISTRY_PASSWORD> --yes --namespace ${namespacename}"

        echo $cmdTemplate > $tmpCmdFile
        extractVariableAndTakeInput $tmpCmdFile
        cmdTemplate=$(cat $tmpCmdFile)

        printf "\nCreating new secret for private registry with name: $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME..."
        $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
        printf "\n"
        rm $tmpCmdFile
        sleep 1
    fi

    # UPDATED: 24/05/2023 ---- NO NEED TO CREATE dockerhub regcred by default. If needed user will create it.
    # printf "\nAlso need to create a dockerhub secret called: dockerhubregcred for Dockerhub rate limiting issue. This credential is used for things like maven test tekton pipeline pulling maven base image etc\n"
    # confirmed=''
    # if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    # then
    #     while true; do
    #         read -p "Would you like to create docker hub secret called 'dockerhubregcred' now? [y/n] " yn
    #         case $yn in
    #             [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
    #             [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
    #             * ) echo "Please answer y or n.";
    #         esac
    #     done
    # else
    #     confirmed='y'
    # fi
    # if [[ $confirmed == 'y' ]]
    # then
    #     local tmpCmdFile=/tmp/devnamespacecmd.tmp
    #     local cmdTemplate="kubectl create secret docker-registry dockerhubregcred --docker-server=https://index.docker.io/v2/ --docker-username=<DOCKERHUB_USERNAME> --docker-password=<DOCKERHUB_PASSWORD> --docker-email=your@email.com --namespace ${namespacename}"

    #     echo $cmdTemplate > $tmpCmdFile
    #     extractVariableAndTakeInput $tmpCmdFile
    #     cmdTemplate=$(cat $tmpCmdFile)

    #     printf "\nCreating new secret with name: dockerhubregcred..."
    #     $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
    #     printf "\n"
    # fi
    

    printf "\nGenerating RBAC, SA for associating TAP and registry using name: default..."
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
        fi
        confirmed='y'
    fi
    if [[ $confirmed == 'y' ]]
    then
        cp $HOME/binaries/templates/workload-ns-setup.yaml /tmp/workload-ns-setup-$namespacename.yaml
        extractVariableAndTakeInput /tmp/workload-ns-setup-$namespacename.yaml

        printf "\n"
        printf "\nCreating RBAC, RoleBinding and associating SA:default with it along with registry and repo credentials..."
        kubectl apply -n $namespacename -f /tmp/workload-ns-setup-$namespacename.yaml && printf "OK" || printf "FAILED"
        printf "\n"
    fi

    isexist=$(cat $tapvaluesfile | grep -w 'scanning:$')
    if [[ -n $isexist ]]
    then
        confirmed='n'
        printf "\nDetected user input for scanning functionlity. A 'kind: ScanPolicy' needs to be present in the namespace.\n"
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
            printf "\nScan policy creation ... COMPLETE\n"
        fi
    fi
    
    printf "\nChecking whether it requires tekton pipeline for testing...."
    isexist=$(cat $tapvaluesfile | grep -i 'supply_chain: testing')
    if [[ -n $isexist ]]
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
        fi
    else
        printf "NO.\nNo supply chain detected with testing functionlity."
    fi

    printf "\n\n**** Developer namespace: $namespacename setup...COMPLETE\n\n\n"
}
