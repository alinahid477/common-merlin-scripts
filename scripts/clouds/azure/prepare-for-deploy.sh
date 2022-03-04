#!/bin/bash

export $(cat $HOME/.env | xargs)

# this is used for both management and tkc
function prepareEnvironment () {
    
    printf "\n${yellowcolor}Checking az cli...${normalcolor}\n"
    local isexist=$(which az)
    if [[ -z isexist ]]
    then
        printf "${redcolor}az cli not found. Installing...${normalcolor}\n"
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    fi
    az version -o table
}

function doLogin () {
    printf "Checking if logged in...\n"
    local isexist=$(az account show | jq -r '.homeTenantId')
    while [[ -z $isexist ]]; do
        printf "${redcolor}not logged in. Log in...${normalcolor}\n"

        if [[ -z $AZ_TKG_APP_ID || -z $AZ_TKG_APP_CLIENT_SECRET || -z $AZ_TENANT_ID ]]
        then
            az login
        else
            printf "${yellowcolot}Login into az using az-cli using service principal...${normalcolor}\n"
            az login --service-principal --username $AZ_TKG_APP_ID --password $AZ_TKG_APP_CLIENT_SECRET --tenant $AZ_TENANT_ID
        fi
        sleep 3

        printf "Checking if logged in...\n"
        isexist=$(az account show | jq -r '.homeTenantId')
    done

    if [[ -z $AZ_TENANT_ID ]]
    then
        printf "Recording tenant id in .env file...\n"
        printf "\nAZ_TENANT_ID=$AZ_TENANT_ID\n" >> $HOME/.env
    fi
}


function createServicePrincipal () {
    local servicePrincipalName=$1
    local servicePrincipalRole=$2

    if [[ -z $servicePrincipalName ]]
    then
        servicePrincipalName='tkg'
        printf "${yellowcolor}Assuming default ServicePrincipal name: $servicePrincipalName.${normalcolor}\n"
    fi
    if [[ -z $servicePrincipalRole ]]
    then
        servicePrincipalRole='owner'
        printf "${yellowcolor}Assuming default ServicePrincipal role: $servicePrincipalRole.${normalcolor}\n"
    fi

    local inp=''
    printf "Variable: SERVICE_PRINCIPAL_NAME\n${bluecolor}Hint: The name of the SP. The name must be fqdn compliant.${normalcolor}\n"
    printf "${greencolor}Press enter to accept default value: $servicePrincipalName ${normalcolor}\n"
    while [[ -z $inp ]]; do
        read -p "input value for SERVICE_PRINCIPAL_NAME: " inp
        if [[ -z $inp ]]
        then
            inp=$servicePrincipalName
        fi
        if [[ ! $inp =~ ^[A-Za-z0-9_-]+$ ]]
        then
            printf "${redcolor}empty or invalid value is not allowed.${normalcolor}\n"
            inp=''
        fi
    done
    servicePrincipalName=$inp
    printf "${greencolor}Accepted service principal name: $servicePrincipalName.${normalcolor}\n"


    inp=''
    printf "Variable: SERVICE_PRINCIPAL_ROLE\n${bluecolor}Hint: The role of the SP. Single or comma seperated multiple value (eg: owner or Network Contributor,Virtual Machine Contributor).\nNote: assign the the Owner role to it if you plan to register your TKC clusters with TMC, or the Virtual Machine Contributor and Network Contributor roles otherwise.${normalcolor}\n"
    printf "${greencolor}Press enter to accept default value: $servicePrincipalRole ${normalcolor}\n"
    while [[ -z $inp ]]; do
        read -p "input value for SERVICE_PRINCIPAL_ROLE: " inp
        if [[ -z $inp ]]
        then
            inp=$servicePrincipalRole
        fi
    done
    servicePrincipalRole=$inp
    printf "${greencolor}Accepted service principal role: $servicePrincipalRole.${normalcolor}\n"


    printf "Creating service principal with name: $servicePrincipalName and role: $servicePrincipalRole...\n"
    
    $servicePrincipalRoleArr=(${servicePrincipalRole//,/ })
    
    local appId=''
    local secret=''
    for role in ${servicePrincipalRoleArr[@]}; do
        if [[ -z $appId ]]
        then
            printf "Performing .. az ad sp create-for-rbac --role \"$role\" --name \"$servicePrincipalName\"...\n"
            local appIdandSecret=$(az ad sp create-for-rbac --role "$role" --name "$servicePrincipalName" | jq -r '.appId+","+.password')
            if [[ -n $appIdandSecretArr ]]
            then
                local appIdandSecretArr=(${appIdandSecret//,/ })
                appId=${appIdandSecretArr[0]}
                secret=${appIdandSecretArr[1]}

                if [[ -n $appId && -n $secret ]]
                then
                    printf "Recording AZ_TKG_APP_ID and AZ_TKG_APP_CLIENT_SECRET in .env file...\n"
                    printf "\nAZ_TKG_APP_ID=$appId\n" >> $HOME/.env
                    printf "\nAZ_TKG_APP_CLIENT_SECRET=$secret\n" >> $HOME/.env
                else
                    returnOrexit || return 1
                fi
            fi
        else
            # this means multiple comma seperated values provided by user
            printf "Performing .. az role assignment create --assignee $appId --role \"$role\"...\n"
            az role assignment create --assignee $appId --role "$role"
        fi
        
    done


    printf "\n\n"

    return 0


}

function prepareAccount () {
    
    while true; do
        export $(cat $HOME/.env | xargs)
        printf "\n${yellowcolor}Checking azure client app (Service Principle) for TKG in environment variable called AZ_TKG_APP_ID and AZ_TKG_APP_CLIENT_SECRET...${normalcolor}\n"
        if [[ -z $AZ_TKG_APP_ID || -z $AZ_TKG_APP_CLIENT_SECRET ]]
        then
            printf "${redcolor}ServicePrincipal information not found\nPlease either fill in the value for AZ_TKG_APP_ID and AZ_TKG_APP_CLIENT_SECRET in .env file OR to create a new one confirm 'y' to below.${normalcolor}\n"
            local confirmation='n'
            
            local confirmation=''
            while true; do
                read -p "Would you like to create Service Principal for tkg? [y/n]: " yn
                case $yn in
                    [Yy]* ) confirmation="y"; printf "you confirmed yes\n"; break;;
                    [Nn]* ) confirmation="n";printf "You confirmed no.\n"; break;;
                    * ) printf "${redcolor}Please answer y or n.${normalcolor}\n";;
                esac
            done
            if [[ $confirmation == 'n' ]]
            then
                printf "${redcolor}Without ServicePrincipal this TKG wizard will not continue.\nAssuming the end user is going to add value for AZ_TKG_APP_ID and AZ_TKG_APP_CLIENT_SECRET in the environment variable...${normalcolor}\n"
            else
                if [[ $confirmation == 'y' ]]
                then
                    createServicePrincipal $SERVICE_PRINCIPAL_NAME $SERVICE_PRINCIPAL_ROLE
                    break
                fi
            fi
        else
            break
        fi
    done
}