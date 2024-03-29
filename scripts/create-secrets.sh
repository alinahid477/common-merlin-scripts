#!/bin/bash

function createGitSSHSecret () {
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

    printf "\n${yellowcolor}Creating Git SSH secret..${normalcolor}\n"
    local confirmed=''
    local namespacename=$1 # Optional. Default: default

    if [[ -z $namespacename ]]
    then
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            printf "\nHint:${bluecolor}the name of the namespace where this secret will be created. eg: default${normalcolor}\n"
            printf "${greencolor}Hit enter to accept default: default${normalcolor}\n"
            while [[ -z $namespacename ]]; do
                read -p "NAMESPACE: " namespacename
                if [[ -z $namespacename ]]
                then
                    namespacename='default'
                    printf "${greencolor}accepted default value: default${normalcolor}\n"
                fi
            done
            # namespacename='default'
        else
            printf "${redcolor}empty namespace name not allowed. Instllation failed @ creating-git-secret.${normalcolor}\n"
            returnOrexit || return 1
        fi
    fi
    if [[ ! -d $HOME/.git-ops ]]
    then
        mkdir -p $HOME/.git-ops
    fi
    
    local identityFileName=''
    if [[ -z $identityFileName ]]
    then
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            printf "\nHint:${bluecolor}identity file name(public and private key files). eg: when identity filename=identity then files are: $HOME/.git-ops/identity and $HOME/.git-ops/identity.pub${normalcolor}\n"
            printf "${greencolor}Hit enter to accept default: identity${normalcolor}\n"
            while [[ -z $identityFileName ]]; do
                read -p "identity prefix: " identityFileName
                if [[ -z $identityFileName ]]
                then
                    identityFileName='identity'
                    printf "${greencolor}accepted default value: identity${normalcolor}\n"
                fi
            done
        else
            identityFileName='identity'
        fi
    fi

    printf "Checking for files: $HOME/.git-ops/$identityFileName and $HOME/.git-ops/$identityFileName.pub..."
    sleep 1
    if [[ ! -f $HOME/.git-ops/$identityFileName || ! -f $HOME/.git-ops/$identityFileName.pub ]]
    then
        printf "Not found.\n"
        sleep 1
        confirmed=''
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            printf "If you already have one unused for git repository confirm 'n' and place the files under $HOME/.git-ops/ directory.\n"
            printf "File names MUST match with name you input previously\n"
            printf "Otherwise, confirm y to create a new one.\n"
            while true; do
                read -p "Would you like to create identity files pair (public and private key pair) for your git repo? [y/n] " yn
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
            local keyemail=''
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                while [[ -z $keyemail ]]; do
                    read -p "Input Email or Username for generating public and private key pair for git ssh: " keyemail
                    if [[ -z $keyemail ]]
                    then
                        printf "WARN: empty value not allowed.\n"
                    fi
                done
            else
                keyemail='merlin_tap_admin@cluster.local'    
            fi
            printf "Generating key pair..."
            ssh-keygen -f $HOME/.git-ops/$identityFileName -q -t rsa -b 4096 -C "$keyemail" -N ""
            sleep 2
            printf "COMPLETE\n"
        fi
    else
        printf "Found in $HOME/.git-ops/.\n"
        sleep 2
    fi

    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        printf "\n\n"
        printf "************************************************\n"
        printf "Here's the generated $HOME/.git-ops/$identityFileName.pub\n"
        cat $HOME/.git-ops/$identityFileName.pub
        sleep 1
        printf "${bluecolor}Please make sure that $identityFileName.pub exists in the gitrepo.\n"
        printf "eg: for bitbucket it is in: https://bitbucket.org/<projectname>/<reponame>/admin/addon/admin/pipelines/ssh-keys\n"
        printf "OR for github it is in: https://github.com/<username>/<reponame>/settings/keys/new${normalcolor}\n"
        printf "************************************************\n"
        sleep 5
        printf "\n\n"
    else
        local gitopsPublicIdentity=$(cat $HOME/.git-ops/$identityFileName.pub)
        local gitopsPrivateIdentity=$(cat $HOME/.git-ops/$identityFileName)
        echo "" >> $HOME/configs/output
        echo "GITOPS_PUBLIC_KEY#$gitopsPublicIdentity" >> $HOME/configs/output
        echo "GITOPS_PRIVATE_KEY#$gitopsPrivateIdentity" >> $HOME/configs/output
        sleep 1
        printf "\n\n"
    fi
    

    

    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        while true; do
            read -p "Confirm to continue to create secret in k8s cluster using the identity file pair? [y/n] " yn
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
        printf "Hint: ${bluecolor}Gitrepo host name. eg: github.com, bitbucket.org${normalcolor}\n"
        local gitprovidername=''
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            while [[ -z $gitprovidername ]]; do
                read -p "Input the hostname of the git repo: " gitprovidername
                if [[ -z $gitprovidername ]]
                then
                    printf "WARN: empty value not allowed.\n"
                fi
            done
        else
            if [[ $GIT_PROVIDER_HOST_NAME =~ ^"http://" ]]
            then
                gitprovidername=${GIT_PROVIDER_HOST_NAME#"http://"}
            elif [[ $GIT_PROVIDER_HOST_NAME =~ ^"https://" ]]
            then
                gitprovidername=${GIT_PROVIDER_HOST_NAME#"https://"}
            else
                gitprovidername=$GIT_PROVIDER_HOST_NAME
            fi
        fi
        if [[ -z $gitprovidername ]]
        then
            printf "${redcolot}empty git provider value not allowed.${normalcolor}\n"
            returnOrexit || return 1
        fi
        printf "Checking $identityFileName-known_hosts file..."
        if [[ ! -f $HOME/.git-ops/$identityFileName-known_hosts ]]
        then
            printf "not found.\n"
            sleep 1
            printf "Creating known_hosts file for $gitprovidername..."
            ssh-keyscan $gitprovidername > $HOME/.git-ops/$identityFileName-known_hosts || returnOrexit || return 1
            printf "COMPLETE\n"
        else
            printf "found.\n"
            sleep 1
        fi

        export GIT_SERVER_HOST=$gitprovidername
        export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.git-ops/$identityFileName | base64 -w 0)
        export GIT_SSH_PUBLIC_KEY=$(cat $HOME/.git-ops/$identityFileName.pub | base64 -w 0)
        export GIT_SERVER_HOST_FILE=$(cat $HOME/.git-ops/$identityFileName-known_hosts | base64 -w 0)
        
        printf "hint: ${bluecolor}Creating $HOME/binaries/templates/gitops-secret-<filename-suffix>.yaml${normalcolor}\n"
        local filename=''
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            while [[ -z $filename ]]; do            
                read -p "Provide a file name suffix for the K8s secret declarative yaml file: " filename
                if [[ -z $filename ]]
                then
                    printf "WARN: empty value not allowed.\n"
                fi
            done
        else
            if [[ -z $GITOPS_SECRET_NAME ]]
            then
                printf "\nDBG: setting GITOPS_SECRET_NAME='git-ssh'\n" && sleep 2
                export GITOPS_SECRET_NAME='git-ssh'
            fi
            filename='git-ssh'
        fi
        cp $HOME/binaries/templates/gitops-secret.yaml /tmp/gitops-secret-$filename.yaml
        extractVariableAndTakeInput /tmp/gitops-secret-$filename.yaml

        test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

        printf "\nCreating git ssh secret..."
        kubectl apply -f /tmp/gitops-secret-$filename.yaml --namespace $namespacename && printf "OK" || printf "FAILED"
        printf "\n"
        if [[ -d $HOME/configs ]]
        then
            cp /tmp/gitops-secret-$filename.yaml $HOME/configs/
        fi
        printf "\n\n\n"
        sleep 3
        unset GIT_SERVER_HOST
        unset GIT_SSH_PRIVATE_KEY
        unset GIT_SSH_PUBLIC_KEY
        unset GIT_SERVER_HOST_FILE
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            unset GITOPS_SECRET_NAME
        fi
    fi
}


function createBasicAuthSecret () {
    
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

    sleep 1
    
    local filesaveDir=$1 # Optional
    local namespace=$2 #optional
    local filename='nouserinput'
    
    if [[ -z $filesaveDir ]]
    then
        filesaveDir=/tmp        
    fi

    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        printf "\nHint:${bluecolor}the name of the namespace where this secret will be created. eg: default${normalcolor}\n"
        printf "${greencolor}Hit enter to accept default: default${normalcolor}\n"
        while [[ -z $namespace ]]; do
            read -p "NAMESPACE: " namespace
            if [[ -z $namespace ]]
            then
                namespace='default'
                printf "${greencolor}accepted default value: default${normalcolor}\n"
            fi
        done        
    fi

    if [[ -z $namespace ]]
    then
        printf "\nempty value for namespace not allowed. Basic Auth Secret creation..FAILED\n"
        returnOrexit || return 1
    fi

    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        filename=''
        while [[ -z $filename ]]; do
            read -p "Provide a file name: " filename
            if [[ -z $filename ]]
            then
                printf "WARN: empty value not allowed.\n"
            fi
        done
    fi

    printf "\nCreating K8s Secret: kubernetes.io/basic-auth in ns: $namespace\n"
    sleep 2
    if [[ -n $SILENTMODE && $SILENTMODE == 'YES' ]]
    then
        if [[ -z $GITOPS_SECRET_NAME ]]
        then
            printf "\nDBG: setting GITOPS_SECRET_NAME='git-secret'\n" && sleep 2
            export GITOPS_SECRET_NAME='git-secret'
        fi
        export K8S_BASIC_SECRET_NAME=$GITOPS_SECRET_NAME
        if [[ $GIT_PROVIDER_HOST_NAME =~ ^"http://" ||  $GIT_PROVIDER_HOST_NAME =~ ^"https://" ]]
        then            
            export K8S_BASIC_SECRET_GIT_SERVER=$GIT_PROVIDER_HOST_NAME
        else            
            export K8S_BASIC_SECRET_GIT_SERVER="https://$GIT_PROVIDER_HOST_NAME"
        fi
        export K8S_BASIC_SECRET_USERNAME=$GIT_USERNAME
        export K8S_BASIC_SECRET_PASSWORD=$GIT_PASSWORD
        if [[ -n $GIT_CA_FILE ]]
        then
            printf "\nDetected CA Cert file to be used for git secret. Reading content of the file: $GIT_CA_FILE...\n"
            sleep 2
            if [[ -f $GIT_CA_FILE ]]
            then
                local pemFileContent=$(cat $GIT_CA_FILE | while read line; do echo "    ${line}"; done)
                export K8S_BASIC_SECRET_CA_CERT=$pemFileContent
            else
                printf "File not found for GIT_CA_FILE: $GIT_CA_FILE\n"
                printf "$GITOPS_SECRET_NAME Secret creation (in SILENTMODE)...FAILED\n"
                sleep 3
                returnOrexit || return 1    
            fi
        fi
        sleep 1
        if [[ -z $K8S_BASIC_SECRET_NAME || -z $K8S_BASIC_SECRET_GIT_SERVER || -z $K8S_BASIC_SECRET_USERNAME || -z $K8S_BASIC_SECRET_PASSWORD ]]
        then
            printf "${redcolot}empty value found for one of the required fields (K8S_BASIC_SECRET_NAME, K8S_BASIC_SECRET_GIT_SERVER, K8S_BASIC_SECRET_USERNAME, K8S_BASIC_SECRET_PASSWORD).${normalcolor}\n"
            printf "$GITOPS_SECRET_NAME Secret creation (in SILENTMODE)...FAILED${normalcolor}\n"
            sleep 3
            returnOrexit || return 1
        fi 
        printf "\nSecret details:\n\tname:$K8S_BASIC_SECRET_NAME\n\tserver:$K8S_BASIC_SECRET_GIT_SERVER\n\tusername:$K8S_BASIC_SECRET_USERNAME\n\n"
    else
        printf "Require input to create k8s secret of type: kubernetes.io/basic-auth....\n"
    fi
    
    local secretTemplateName="k8s-basic-auth-git-secret"
    if [[ -n $K8S_BASIC_SECRET_CA_CERT ]]
    then
        secretTemplateName="k8s-basic-auth-git-secret-with-cacert"
    fi
    local secretFile=$filesaveDir/$secretTemplateName.$filename.tmp
    cp $HOME/binaries/templates/$secretTemplateName.template $secretFile
    sleep 1
    extractVariableAndTakeInput $secretFile || returnOrexit || return 1
    printf "\nsecret yaml...complete\n"
    
    printf "Creating k8s secret of type kubernetes.io/basic-auth...."
    kubectl apply -f $secretFile -n $namespace && printf "CREATED\n" || printf "FAILED\n"
    sleep 1
    if [[ $filesaveDir == '/tmp' ]]
    then
        rm $secretFile
    fi
}

function createDockerRegistrySecret () {
    printf "Require user input to create K8s secret of type docker-registry...\n"
    local tmpCmdFile=/tmp/kubectl-docker-registry-secret-cmd.tmp
    local cmdTemplate="kubectl create secret docker-registry <DOCKER_REGISTRY_SECRET_NAME> --docker-server <DOCKER_REGISTRY_SERVER> --docker-username <DOCKER_REGISTRY_USERNAME> --docker-password <DOCKER_REGISTRY_PASSWORD> --namespace <DOCKER_REGISTRY_SECRET_NAMESPACE>"

    echo $cmdTemplate > $tmpCmdFile
    extractVariableAndTakeInput $tmpCmdFile
    cmdTemplate=$(cat $tmpCmdFile)
    rm $tmpCmdFile
    printf "\nCreating new K8s secret of type docker-registry..."
    $(echo $cmdTemplate) && printf "CREATED" || printf "FAILED"
    printf "\n"
}


function createServiceAccount () {

    local filesaveDir=$1 # Optional
    local filename='nouserinput'

    local serviceAccountNameSpace=$2

    if [[ -z $serviceAccountNameSpace ]]
    then
        serviceAccountNameSpace='default'
    fi

    if [[ -z $filesaveDir ]]
    then
        filesaveDir=/tmp
    else
        filename=''
        while [[ -z $filename ]]; do
            read -p "Provide a file name: " filename
            if [[ -z $filename ]]
            then
                printf "WARN: empty value not allowed.\n"
            fi
        done
    fi
    if [[ -n $K8S_SERVICE_ACCOUNT_NAMESPACE ]]
    then
        serviceAccountNameSpace=$K8S_SERVICE_ACCOUNT_NAMESPACE
    fi
    
    local saTemplateName="k8s-service-account"
    local saFile=$filesaveDir/$saTemplateName.$filename.yaml
    cp $HOME/binaries/templates/$saTemplateName.template $saFile
    extractVariableAndTakeInput $saFile || returnOrexit || return 1
    local confirmed=''
    while true; do
        read -p "Would you like to add more secrets (eg: git-secret) to this service account? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done  
    if [[ $confirmed == 'y' ]]
    then
        local secretTemplateName="k8s-service-account-secrets"
        local secretFile=/tmp/$secretTemplateName.tmp
        cp $HOME/binaries/templates/$secretTemplateName.template $secretFile
        extractVariableAndTakeInput $secretFile || returnOrexit || return 1
        cat $secretFile >> $saFile
        rm $secretFile
    fi
    printf "Applying $saFile for k8s service account in namespace: $serviceAccountNameSpace...."
    kubectl apply -f $saFile -n $serviceAccountNameSpace && printf "CREATED\n" || printf "FAILED\n"

    if [[ $filesaveDir == '/tmp' ]]
    then
        rm $saFile
    fi
}