#!/bin/bash

function installAZCLI () {
    local isexistsaz=$(which az)
    if [[ -z $isexistsaz ]]
    then
        printf "\naz cli not found. Installing...\n"
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    else
        printf "\naz cli found. No need to install new.\n"
        return 0
    fi

    local isexistsaz1=$(which az)
    if [[ -z $isexistsaz1 ]]
    then
        printf "\naz cli STILL not found. Exiting...\n"
        returnOrexit || return 1
    fi
    return 0
}

function installAWSCLI () {
    local isexistsaws=$(which aws)
    if [[ -z $isexistsaws ]]
    then
        printf "\naws cli not found. Installing...\n"
        if [[ ! -d $HOME/awscli ]]
        then
            mkdir -p $HOME/awscli
        fi
        local removezip=''
        if [[ ! -d $HOME/awscli/aws ]]
        then
            printf "\naws cli binary not found. Downloading...\n"
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o $HOME/awscli/awscliv2.zip
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

    local isexistsaws1=$(which aws)
    if [[ -z $isexistsaws1 ]]
    then
        printf "\naws cli STILL not found. Exiting...\n"
        returnOrexit || return 1
    fi
    return 0
}


function installCloudCLI () {
    local cloudname=$1

    if [[ -z $cloudname || (( $cloudname != 'vsphere' && $cloudname != 'aws' && $cloudname != 'azure' )) ]]
    then
        printf "\n\n${redcolor}ERROR: invalid cloud name provided for installing cloud cli.${normalcolor}\n\n"
        returnOrexit || return 1
    fi

    if [[ $cloudname == 'aws' ]]
    then
        installAWSCLI || returnOrexit || return 1
        return 0
    fi
    if [[ $cloudname == 'azure' ]]
    then
        installAZCLI || returnOrexit || return 1
        return 0
    fi
    if [[ $cloudname == 'vsphere' ]]
    then
        
        return 0
    fi

    return 1
}