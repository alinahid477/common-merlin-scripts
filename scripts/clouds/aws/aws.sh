#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/install-cloud-cli.sh

function prepareEnvironment () {
    installAWSCLI || returnOrexit || return 1

    return 0
}


function doLogin () {
    export $(cat $HOME/.env | xargs)

    printf "\n\n"

    printf "Checking if can log in...\n"
    local isexist=$(aws sts get-caller-identity)
    if [[ -z $isexist ]]
    then
        printf "\n${redcolor}ERROR: invalid aws access.${normalcolor}\n"
        returnOrexit || return 1
    fi
}


function createKeyPair () {
    export $(cat $HOME/.env | xargs)

    if [[ -z $AWS_REGION ]]
    then
        printf "\n${redcolor}AWS_REGION must exists with valid value.${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "\nChecking Key pair validity with name $AWS_REGION-tkg-keypair in the region $AWS_REGION..."

    local kpName=$(aws ec2 describe-key-pairs --key-name $AWS_REGION-tkg-keypair --region $AWS_REGION --output text | awk '{print $3}')
    local kpFileName=$(ls -l $HOME/.ssh/$AWS_REGION-tkg-keypair.pem)
    printf "CHECKED\n"
    if [[ -n $kpName && -n $kpFileName ]]
    then
        printf "${greencolor}Key Pair already exists, no need to create a new one.${normalcolor}\n"
    else
        createnew='n'
        if [[ -n $kpName ]]
        then
            printf "${yellowcolor}WARN: KeyPair exist in AWS but missing in local $HOME/.ssh/$AWS_REGION-tkg-keypair.pem.\nDeleting exisitng key pair $kpName from AWS $AWS_REGION...${normalcolor}"
            aws ec2 delete-key-pair --key-name $kpName --region $AWS_REGION
            createnew='y'
            printf "DELETED.\n"
        fi

        if [[ -n $kpFileName ]]
        then
            printf "Key pair file exists in local: $HOME/.ssh/$AWS_REGION-tkg-keypair.pem BUT is not associated with AWS region.\n"
            printf "Importing file://$HOME/.ssh/$AWS_REGION-tkg-keypair.pem to AWS Account for region $AWS_REGION with name: $AWS_REGION-tkg-keypair..."    
            aws ec2 import-key-pair --key-name  $AWS_REGION-tkg-keypair --public-key-material file://$HOME/.ssh/$AWS_REGION-tkg-keypair.pem
            printf "IMPORTED.\n"
        fi

        if [[ $createnew == 'y' ]]
        then
            printf "${bluecolor}No key pair found in local or in aws region: $AWS_REGION.${normalcolor}}\n"
            printf "Registering an SSH Public Key with Your AWS Account in region $AWS_REGION and creating localfile: $HOME/.ssh/$AWS_REGION-tkg-keypair.pem..."
            aws ec2 create-key-pair --key-name $AWS_REGION-tkg-keypair --output json --region $AWS_REGION | jq .KeyMaterial -r > $HOME/.ssh/$AWS_REGION-tkg-keypair.pem
            printf "REGISTERED.\n"
        fi      
    fi

    printf "\n\nKey-Pair created. To review visit https://$AWS_REGION.console.aws.amazon.com/ec2/v2/home?region=$AWS_REGION#KeyPairs:"
    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; break;;
            [Nn]* ) printf "You said no.\n"; returnOrexit || return 1;;
            * ) printf "${redcolor}Please answer yes or no.${normalcolor}\n";;
        esac
    done
}


function prepareAccountForTKG () {
    prepareEnvironment || returnOrexit || return 1

    while true; do
        export $(cat $HOME/.env | xargs)
        printf "\nDocumentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.5/vmware-tanzu-kubernetes-grid-15/GUID-mgmt-clusters-aws.html#cluster-configuration-file-11\n"
        printf "\n${bluecolor}Checking aws access informartion for TKG in environment variable called AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY...${normalcolor}\n"
        sleep 1
        if [[ -z $AWS_ACCESS_KEY_ID || -z $AWS_SECRET_ACCESS_KEY ]]
        then
            printf "${redcolor}AWS AccessKey and Secret not found.\nPlease either fill in the value for AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env file. Confirm 'y' when the value is added to .env file. Confirm 'n' to exit.${normalcolor}\n"
            local confirmation='n'
            while true; do
                read -p "Confirmation? [y/n]: " yn
                case $yn in
                    [Yy]* ) confirmation="y"; printf "you confirmed yes\n"; break;;
                    [Nn]* ) confirmation="n";printf "You confirmed no.\n"; break;;
                    * ) printf "${redcolor}Please answer y or n.${normalcolor}\n";;
                esac
            done
            if [[ $confirmation == 'n' || -z $AWS_ACCESS_KEY_ID || -z $AWS_SECRET_ACCESS_KEY ]]
            then
                printf "${redcolor}Without AWS access key or ID this wizard will not continue.${normalcolor}\n\n"
                returnOrexit || return 1               
            fi
            if [[ $confirmation == 'y' ]]
            then
                doLogin || returnOrexit || return 1
                sleep 1
                break
            fi
        else
            doLogin || returnOrexit || return 1
            break
        fi
    done

    local awsRegion=''
    while [[ -z $awsRegion ]]; do
        read -p "AWS_REGION: " awsRegion
        if [[ -n $awsRegion ]]
        then
            sed -i '/AWS_REGION/d' $HOME/.env
            printf "\nAWS_REGION=$awsRegion\n" >> $HOME/.env
        fi
    done

    export $(cat $HOME/.env | xargs)

    printf "\n${yellowcolor}AWS region=$AWS_REGION\nConfirm y to continue or n to exit.${normalcolor}\n"

    while true; do
        read -p "Confirmation? [y/n]: " yn
        case $yn in
            [Yy]* ) confirmation="y"; printf "you confirmed yes\n"; break;;
            [Nn]* ) confirmation="n";printf "You confirmed no.\n"; returnOrexit || return 1;;
            * ) printf "${redcolor}Please answer y or n.${normalcolor}\n";;
        esac
    done

    createKeyPair || returnOrexit || return 1

    return 0
}