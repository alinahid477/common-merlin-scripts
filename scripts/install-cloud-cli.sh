#!/bin/bash

function installAZCLI () {
    local isexists=$(which az)
    if [[ -z $isexists ]]
    then
        printf "\naz cli not found. Installing...\n"
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    else
        printf "\naz cli found. No need to install new.\n"
        return 0
    fi

    isexists=$(which az)
    if [[ -z $isexists ]]
    then
        printf "\naz cli STILL not found. Exiting...\n"
        returnOrexit || return 1
    fi
    return 0
}

function installAWSCLI () {
    local isexists=$(which aws)
    if [[ -z $isexists ]]
    then
        printf "\naws cli not found. Installing...\n"
        if [[ ! -d $HOME/awscli ]]
        then
            mkdir awscli
        fi
        local removezip=''
        if [[ ! -d $HOME/awscli/aws ]]
        then
            printf "\naws cli binary not found. Downloading...\n"
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o $HOME/aws/awscliv2.zip
            cd $HOME/awscli/
            unzip awscliv2.zip
            $removezip=true
        fi
        printf "\ninstalling cli...\n"
        cd $HOME/awscli/
        ./aws/install
        if [[ $removezip == true ]]
        then
            rm -rf awscliv2.zip
        fi
        cd ~
        aws --version
    else
        printf "\naws cli found. No need to install new.\n"
        return 0
    fi

    isexists=$(which aws)
    if [[ -z $isexists ]]
    then
        printf "\naws cli STILL not found. Exiting...\n"
        returnOrexit || return 1
    fi
    return 0
}
