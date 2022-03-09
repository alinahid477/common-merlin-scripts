#!/bin/bash

function installAZCLI () {
    local isexists=$(which az)
    if [[ -z $isexists ]]
    then
        printf "\naz cli not found. Installing...\n"
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    else
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
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        $HOME/aws/install
        rm -rf awscliv2.zip
    else
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
