#!/bin/bash

function createGitSSHSecret () {
    export $(cat $HOME/.env | xargs)

    printf "\n${yellowcolor}Creating Git SSH secret..${normalcolor}\n"

    local namespacename=$1 # Optional. Default: default

    if [[ -z $namespacename ]]
    then
        namespacename='default'
    fi
    if [[ ! -d $HOME/.git-ops ]]
    then
        mkdir -p $HOME/.git-ops
    fi
    
    if [[ ! -f $HOME/.git-ops/identity || ! -f $HOME/.git-ops/identity.pub ]]
    then
        printf "Identity files for git repository (public and private key files) not found.\n"
        printf "If you already have one for git repository confirm 'n' and place the files in $HOME/.git-ops/ directory.\n"
        printf "File names MUST be with name identity and identity.pub\n"
        printf "Otherwise, confirm y to create a new one.\n"
        while true; do
            read -p "Would you like to create identity file for your git repo? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done

        if [[ $confirmed == 'y' ]]
        then
            local keyemail=''
            while [[ -z $keyemail ]]; do
                read -p "Input Email or Username for generating public and private key pair for git ssh: " keyemail
                if [[ -z $keyemail ]]
                then
                    printf "WARN: empty value not allowed.\n"
                fi
            done
            printf "Generating key pair..."
            ssh-keygen -f $HOME/.git-ops/identity -q -t rsa -b 4096 -C "$keyemail" -N ""
            sleep 2
            printf "COMPLETE\n"
        fi
    else
        printf "Git repo identity keypair for GitOps found in $HOME/.git-ops/.\n"
        sleep 2
    fi

    printf "${bluecolor}Please make sure that identity.pub exists in the gitrepo.\n"
    printf "eg: for bitbucket it is in: https://bitbucket.org/<projectname>/<reponame>/admin/addon/admin/pipelines/ssh-keys\n"
    printf "OR for githun it is in: https://github.com/<username>/<reponame>/settings/keys/new${normalcolor}\n"
    sleep 2

    printf "Here's identity.pub\n"
    cat $HOME/.git-ops/identity.pub
    sleep 2
    printf "\n\n"
    while true; do
        read -p "Confirm to continue to create secret in k8s cluster using the Git repo keypair? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done

    if [[ $confirmed == 'y' ]]
    then
        if [[ ! -f $HOME/.git-ops/known_hosts ]]
        then
            printf "Hint: ${bluecolor}Gitrepo host name. eg: github.com, bitbucket.org${normalcolor}\n"

            local gitprovidername=''
            while [[ -z $gitprovidername ]]; do
                read -p "Input the hostname of they git repo: " gitprovidername
                if [[ -z $gitprovidername ]]
                then
                    printf "WARN: empty value not allowed.\n"
                fi
            done

            printf "Creating known_hosts file for $gitprovidername..."
            ssh-keyscan $gitprovidername > $HOME/.git-ops/known_hosts || returnOrexit || return 1
            printf "COMPLETE\n"
        fi

        export GIT_SERVER_HOST=$gitprovidername
        export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.git-ops/identity | base64 -w 0)
        export GIT_SSH_PUBLIC_KEY=$(cat $HOME/.git-ops/identity.pub | base64 -w 0)
        export GIT_SERVER_HOST_FILE=$(cat $HOME/.git-ops/known_hosts | base64 -w 0)
        
        local filename=''
        while [[ -z $filename ]]; do
            read -p "Provide a file name: " filename
            if [[ -z $filename ]]
            then
                printf "WARN: empty value not allowed.\n"
            fi
        done
        cp $HOME/binaries/templates/gitops-secret.yaml /tmp/gitops-secret-$filename.yaml
        extractVariableAndTakeInput /tmp/gitops-secret-$filename.yaml

        export $(cat $HOME/.env | xargs)

        printf "\nCreating git ssh secret: $GITOPS_SECRET_NAME..."
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
    fi
}