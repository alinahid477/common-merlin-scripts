#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/install-cloud-cli.sh

function prepareEnvironment () {
    printf "\nPrepare aws cli...\n"
    installAWSCLI || returnOrexit || return 1

    return 0
}


function doLogin () {

    printf "\nCheking access to AWS account for region...\n"

    export $(cat $HOME/.env | xargs)

    if [[ -z $AWS_REGION ]]
    then
        printf "${yellowcolor}AWS_REGION not set in environment variable.\nProvide a valid aws region (eg: us-west-2) or type 'none' to not provide any${normalcolor}\n"
        local awsRegion=''
        while [[ -z $awsRegion ]]; do
            read -p "AWS_REGION: " awsRegion
            if [[ -n $awsRegion && $awsRegion != 'none' ]]
            then
                sed -i '/AWS_REGION/d' $HOME/.env
                printf "\nAWS_REGION=$awsRegion\n" >> $HOME/.env
            fi
        done
    fi
    
    export $(cat $HOME/.env | xargs)

    if [[ -z $AWS_REGION ]]
    then
        printf "\n${redcolor}ERROR: AWS_REGION must exist for checking aws access.${normalcolor}\n"
    fi

    printf "Checking credential validity..."
    local isexistaws=$(aws sts get-caller-identity)
    if [[ -z $isexistaws ]]
    then
        printf "\n${redcolor}ERROR: invalid aws access.${normalcolor}\n"
        returnOrexit || return 1
    else
        printf "${greencolor}VALID.${normalcolor}\n"
    fi
}

function doAWSConfigure () {

    printf "\nPerforming aws configure...\n"

    if [[ -f $HOME/.aws/credentials ]]
    then
        printf "${bluecolor}AWS configuration already exist. No need to create new one. Skipping...${normalcolor}\n"
        return 0
    fi

    
    local issso=false
    # if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    # then
    #     while true; do
    #         read -p "Confirm is you would like to use sso [y/n]: " yn
    #         case $yn in
    #             [Yy]* ) issso=true; printf "\nyou confirmed yes\n"; break;;
    #             [Nn]* ) printf "\nYou said no.\n"; break;;
    #             * ) printf "${redcolor}Please answer y or n.${normalcolor}\n";;
    #         esac
    #     done
    # fi

    if [[ $issso == false ]]
    then
        printf "User Name,Access key ID,Secret access key,Default region name,profile\n" > /tmp/awsconfigure.csv
        printf "merlin,$AWS_ACCESS_KEY_ID,$AWS_SECRET_ACCESS_KEY,$AWS_REGION,merlin-tkg" >> /tmp/awsconfigure.csv

        aws configure import --csv "file:///tmp/awsconfigure.csv" --region $AWS_REGION --profile "merlin-tkg"
    else
        aws configure sso
    fi

}


function getKeyPairName () {
    export $(cat $HOME/.env | xargs)

    if [[ -z $AWS_REGION ]]
    then
        returnOrexit || return 1
    fi
    local kpName=$(aws ec2 describe-key-pairs --key-name $AWS_REGION-tkg-keypair --region $AWS_REGION --output text | awk '{print $3}')
    printf $kpName

    return 0
}

function createKeyPair () {

    printf "\nCreating key pair for TKG in AWS region...\n"
    sleep 2

    export $(cat $HOME/.env | xargs)

    if [[ -z $AWS_REGION ]]
    then
        printf "\n${redcolor}AWS_REGION must exists with valid value.${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "\nChecking Key pair validity with name $AWS_REGION-tkg-keypair in the region $AWS_REGION..."
    local isexistpair=''
    local kpName=$(aws ec2 describe-key-pairs --key-name $AWS_REGION-tkg-keypair --region $AWS_REGION --output text | awk '{print $3}')
    local kpFileName=$(ls -l $HOME/.ssh/$AWS_REGION-tkg-keypair.pem)
    printf "CHECKED\n"
    if [[ -n $kpName && -n $kpFileName ]]
    then
        printf "${greencolor}Key Pair already exists, no need to create a new one.${normalcolor}\n"
        isexistpair=true
    else
        if [[ -n $kpName ]]
        then
            printf "${yellowcolor}WARN: KeyPair exist in AWS but missing in local $HOME/.ssh/$AWS_REGION-tkg-keypair.pem.\nDeleting exisitng key pair $kpName from AWS $AWS_REGION...${normalcolor}"
            aws ec2 delete-key-pair --key-name $kpName --region $AWS_REGION
            printf "DELETED.\n"
        fi

        if [[ -n $kpFileName ]]
        then
            printf "Key pair file exists in local: $HOME/.ssh/$AWS_REGION-tkg-keypair.pem BUT is not associated with AWS region.\n"
            printf "Importing file://$HOME/.ssh/$AWS_REGION-tkg-keypair.pem to AWS Account for region $AWS_REGION with name: $AWS_REGION-tkg-keypair..."    
            aws ec2 import-key-pair --key-name  $AWS_REGION-tkg-keypair --public-key-material fileb://$HOME/.ssh/$AWS_REGION-tkg-keypair.pem || returnOrexit || return 1
            printf "IMPORTED.\n"
            isexistpair=true
        fi

        if [[ -z $isexistpair ]]
        then
            printf "${bluecolor}No key pair found in local or in aws region: $AWS_REGION.${normalcolor}\n"
            printf "Registering an SSH Public Key with Your AWS Account in region $AWS_REGION and creating localfile: $HOME/.ssh/$AWS_REGION-tkg-keypair.pem..."
            aws ec2 create-key-pair --key-name $AWS_REGION-tkg-keypair --output json --region $AWS_REGION | jq .KeyMaterial -r > $HOME/.ssh/$AWS_REGION-tkg-keypair.pem || returnOrexit || return 1
            local isexistcat=$(cat $HOME/.ssh/$AWS_REGION-tkg-keypair.pem)
            if [[ -z $isexistcat ]]
            then
                printf "${redcolor}ERROR: empty pem file${normalcolor}\n"
                rm $HOME/.ssh/$AWS_REGION-tkg-keypair.pem
                returnOrexit || return 1
            fi
            printf "REGISTERED.\n"
            isexistpair=true
        fi      
    fi

    if [[ $isexistpair == true ]]
    then
        printf "${greencolor}Key-Pair created. To review visit https://$AWS_REGION.console.aws.amazon.com/ec2/v2/home?region=$AWS_REGION#KeyPairs:${normalcolor}\n"
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; break;;
                [Nn]* ) printf "You said no.\n"; returnOrexit || return 1;;
                * ) printf "${redcolor}Please answer y or n.${normalcolor}\n";;
            esac
        done
    else
        printf "\n\n${redcolor}ERROR: failed to create key-pair in aws.${normalcolor}\n"
        returnOrexit || return 1
    fi
    
    return 0
}


function prepareAccountForTKG () {

    printf "\nPreparing AWS account in the region for TKG...\n"
    printf "Documentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.5/vmware-tanzu-kubernetes-grid-15/GUID-mgmt-clusters-aws.html#cluster-configuration-file-11\n"
    sleep 2

    prepareEnvironment || returnOrexit || return 1

    while true; do
        export $(cat $HOME/.env | xargs)
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
            printf "Access Key and Secret is present.\n"
            doLogin || returnOrexit || return 1
            break
        fi
    done

    doAWSConfigure

    createKeyPair || returnOrexit || return 1

    return 0
}