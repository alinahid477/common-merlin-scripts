#!/bin/bash

export $(cat $HOME/.env | xargs)
source $HOME/binaries/scripts/install-cloud-cli.sh
# this is used for both management and tkc
function prepareEnvironment () {
    installAZCLI || returnOrexit || return 1

    return 0
}

function doLogin () {
    export $(cat $HOME/.env | xargs)

    if [[ ((-z $AZ_APP_ID || -z $AZ_APP_CLIENT_SECRET || -z $AZ_TENANT_ID)) && -d "$HOME/.azure" ]]
    then
        printf "${yellowcolot}App registration does not exist or not complete...\nRemoving .azure dir...${normalcolor}\n"
        sed -i '/AZ_TENANT_ID/d' $HOME/.env
        sed -i '/AZ_SUBSCRIPTION_ID/d' $HOME/.env
        rm -r $HOME/.azure/
    fi

    printf "\n\n"

    printf "Checking if logged in...\n"
    local tenantId=$(az account show | jq -r '.tenantId')
    while [[ -z $tenantId ]]; do
        printf "${redcolor}not logged in. Log in...${normalcolor}\n"

        if [[ -z $AZ_APP_ID || -z $AZ_APP_CLIENT_SECRET || -z $AZ_TENANT_ID ]]
        then
            az login || returnOrexit || return 1
            # what if only tenant id is missing somehow?
            # the below logic will take care of it
            if [[ -n $AZ_APP_ID && -n $AZ_APP_CLIENT_SECRET ]]
            then
                printf "${yellowcolot}service principal is present but tenant id is missing. fixing this...${normalcolor}\n"    
                tenantId=$(az account show | jq -r '.tenantId')
                if [[ -n $tenantId ]]
                then
                    printf "${yellowcolot}Found tenant id: $tenantId. Logout and login using service principal.${normalcolor}\n"    
                    sleep 1
                    az logout
                    az login --service-principal --username $AZ_APP_ID --password $AZ_APP_CLIENT_SECRET --tenant $AZ_TENANT_ID || returnOrexit || return 1
                fi    
            fi
        else
            printf "${yellowcolot}Login into az using az-cli using service principal...${normalcolor}\n"
            az login --service-principal --username $AZ_APP_ID --password $AZ_APP_CLIENT_SECRET --tenant $AZ_TENANT_ID || returnOrexit || return 1
        fi
        sleep 3

        printf "Checking if logged in...\n"
        tenantId=$(az account show | jq -r '.tenantId')
    done

    if [[ -z $AZ_TENANT_ID && -n $tenantId ]]
    then
        printf "Recording tenant id in .env file...\n"
        sed -i '/AZ_TENANT_ID/d' $HOME/.env
        printf "\nAZ_TENANT_ID=$tenantId\n" >> $HOME/.env
    else
        if [[ "$AZ_TENANT_ID" != "$tenantId" ]]
        then
            printf "${redcolor}AZ_TENANT_ID from .env and logged in tenant id does not match (\"$AZ_TENANT_ID\" != \"$tenantId\")\nLogin failed...${normalcolor}\n"
            returnOrexit || return 1
        fi
    fi
    sleep 1
    local id=$(az account show | jq -r '.id')
    if [[ -z $AZ_SUBSCRIPTION_ID && -n $id ]]
    then
        printf "Recording subscription id in .env file...\n"
        sed -i '/AZ_SUBSCRIPTION_ID/d' $HOME/.env
        printf "\nAZ_SUBSCRIPTION_ID=$id\n" >> $HOME/.env
    else
        if [[ "$AZ_SUBSCRIPTION_ID" != "$id" ]]
        then
            printf "${redcolor}AZ_SUBSCRIPTION_ID from .env and logged in subscription id does not match (\"$AZ_SUBSCRIPTION_ID\" != \"$id\")\nLogin failed...${normalcolor}\n"
            returnOrexit || return 1
        fi
    fi

    export $(cat $HOME/.env | xargs)

    return 0
}




function acceptBaseImageLicense () {
    local baseImageName=$1

    export $(cat $HOME/.env | xargs)
    printf "\n\n"

    if [[ -z $AZ_SUBSCRIPTION_ID ]]
    then
        printf "${redcolor}ERROR: Subscrption id not found in environment variable.${normalcolor}\n"
        returnOrexit || return 1
    fi

    local isUserInputRequired='n'
    # if [[ -z $baseImageName ]]
    # then
    #     baseImageName=$BASE_IMAGE_NAME
    # fi
    if [[ -z $baseImageName ]]
    then
        isUserInputRequired='y'
        baseImageName='k8s-1dot22dot5-ubuntu-2004'
    fi

    if [[ $isUserInputRequired == 'y' ]]
    then
        local inp=''
        printf "Variable: BASE_IMAGE_NAME\n${bluecolor}Hint: Base image license needs to accepted. In TKG v1.5.1, the default cluster image is k8s-1dot22dot5-ubuntu-2004, based on Kubernetes version 1.22.5 and the machine OS, Ubuntu 20.04. ${normalcolor}\n"
        printf "${greencolor}Press enter to accept default value: $baseImageName ${normalcolor}\n"
        while [[ -z $inp ]]; do
            read -p "input value for BASE_IMAGE_NAME: " inp
            if [[ -z $inp ]]
            then
                inp=$baseImageName
            fi
            if [[ ! $inp =~ ^[A-Za-z0-9_\-]+$ ]]
            then
                printf "${redcolor}Invalid value is not allowed.${normalcolor}\n"
                inp=''
            fi
        done
        baseImageName=$inp
        printf "${greencolor}Accepted base image name: $baseImageName.${normalcolor}\n"
    else 
        printf "${yellowcolor}Supplied base image name: $baseImageName.${normalcolor}\n"
    fi

    printf "Executing az vm image terms accept --publisher vmware-inc --offer tkg-capi --plan $baseImageName --subscription $AZ_SUBSCRIPTION_ID...\n"
    az vm image terms accept --publisher vmware-inc --offer tkg-capi --plan $baseImageName --subscription $AZ_SUBSCRIPTION_ID || returnOrexit || return 1


    if [[ -z $BASE_IMAGE_NAME || (( -n $baseImageName && $baseImageName != $BASE_IMAGE_NAME )) ]]
    then
        printf "Recording BASE_IMAGE_NAME in .env file...\n"
        sed -i '/BASE_IMAGE_NAME/d' $HOME/.env
        printf "\nBASE_IMAGE_NAME=$baseImageName\n" >> $HOME/.env
    fi

    return 0
}

function createServicePrincipal () {
    local servicePrincipalName=$1
    local servicePrincipalRole=$2

    printf "\n\n"

    local isUserInputRequired='n'

    if [[ -z $servicePrincipalName ]]
    then
        isUserInputRequired='y'
        servicePrincipalName='tanzu'
        printf "${yellowcolor}Assuming default ServicePrincipal name: $servicePrincipalName.${normalcolor}\n"
    fi
    if [[ -z $servicePrincipalRole ]]
    then
        isUserInputRequired='y'
        servicePrincipalRole='owner'
        printf "${yellowcolor}Assuming default ServicePrincipal role: $servicePrincipalRole.${normalcolor}\n"
    fi

    if [[ $isUserInputRequired == 'y' ]]
    then
        local inp=''
        printf "Variable: SERVICE_PRINCIPAL_NAME\n${bluecolor}Hint: The name of the SP. The name must be fqdn compliant.${normalcolor}\n"
        printf "${greencolor}Press enter to accept default value: $servicePrincipalName ${normalcolor}\n"
        while [[ -z $inp ]]; do
            read -p "input value for SERVICE_PRINCIPAL_NAME: " inp
            if [[ -z $inp ]]
            then
                inp=$servicePrincipalName
            fi
            if [[ ! $inp =~ ^[A-Za-z0-9_\-]+$ ]]
            then
                printf "${redcolor}Invalid value is not allowed.${normalcolor}\n"
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
    fi
    

    printf "Creating service principal with name: $servicePrincipalName and role: $servicePrincipalRole...\n"
    
    local servicePrincipalRoleArr=(${servicePrincipalRole//,/ })
    
    local appId=''
    local secret=''
    for role in ${servicePrincipalRoleArr[@]}; do
        if [[ -z $appId ]]
        then
            printf "Performing .. az ad sp create-for-rbac --role \"$role\" --name \"$servicePrincipalName\" --scope  /subscriptions/$AZ_SUBSCRIPTION_ID...\n"
            local appIdandSecret=$(az ad sp create-for-rbac --role "$role" --name "$servicePrincipalName" --scope  /subscriptions/$AZ_SUBSCRIPTION_ID | jq -r '.appId+","+.password')
            if [[ -n $appIdandSecret ]]
            then
                printf "\nDEBUG: $appIdandSecret\n"
                local appIdandSecretArr=(${appIdandSecret//,/ })
                appId=${appIdandSecretArr[0]}
                secret=${appIdandSecretArr[1]}

                if [[ -n $appId && -n $secret ]]
                then
                    printf "Recording AZ_APP_ID and AZ_APP_CLIENT_SECRET in .env file...\n"
                    sed -i '/AZ_APP_ID/d' $HOME/.env
                    sed -i '/AZ_APP_CLIENT_SECRET/d' $HOME/.env
                    printf "\nAZ_APP_ID=$appId\n" >> $HOME/.env
                    printf "\nAZ_APP_CLIENT_SECRET=$secret\n" >> $HOME/.env
                else
                    printf "${redcolor}ERROR: Something went wrong...$normalcolor\n"
                    returnOrexit || return 1
                fi
            else
                printf "${redcolor}ERROR: Something went wrong...{}$normalcolor\n"
                returnOrexit || return 1
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
    prepareEnvironment || returnOrexit || return 1

    while true; do
        export $(cat $HOME/.env | xargs)
        printf "\n${bluecolor}Checking azure client app (Service Principle) in environment variable called AZ_APP_ID and AZ_APP_CLIENT_SECRET...${normalcolor}\n"
        sleep 1
        if [[ -z $AZ_APP_ID || -z $AZ_APP_CLIENT_SECRET ]]
        then
            printf "${redcolor}ServicePrincipal information not found\nPlease either fill in the value for AZ_APP_ID and AZ_APP_CLIENT_SECRET in .env file and confirm 'n'\nOR to create a new one confirm 'y' to below.${normalcolor}\n"
            local confirmation='n'
            while true; do
                read -p "Would you like to create a NEW Service Principal? [y/n]: " yn
                case $yn in
                    [Yy]* ) confirmation="y"; printf "you confirmed yes\n"; break;;
                    [Nn]* ) confirmation="n";printf "You confirmed no.\n"; break;;
                    * ) printf "${redcolor}Please answer y or n.${normalcolor}\n";;
                esac
            done
            if [[ $confirmation == 'n' && ((-z $AZ_APP_ID || -z $AZ_APP_CLIENT_SECRET)) ]]
            then
                printf "${redcolor}Without ServicePrincipal this wizard will not continue.\nAssuming the end user is going to add value for AZ_APP_ID and AZ_APP_CLIENT_SECRET in the environment variable...${normalcolor}\n"
            else
                if [[ $confirmation == 'y' ]]
                then
                    doLogin || returnOrexit || return 1
                    sleep 1
                    createServicePrincipal $SERVICE_PRINCIPAL_NAME $SERVICE_PRINCIPAL_ROLE || returnOrexit || return 1
                    sleep 1
                    printf "${yellowcolor}service principal creation complete. Logging out to login using SP... $normalcolor\n"
                    az logout
                    sleep 1
                    if [[ -d "$HOME/.azure" ]]
                    then
                        # remove .azure dir created during login.
                        # as we are going to use ServicePrincipal to login going forward we no longer require the .azure dir during user login using az login
                        # the .azure dir also conflicts with az login --service-principal hence it is CRITICAL that this dir is removed before performing az login --service-principal
                        rm -r $HOME/.azure/
                        sleep 1
                    fi
                    doLogin || returnOrexit || return 1
                    break
                fi
            fi
        else
            doLogin || returnOrexit || return 1
            break
        fi
    done
}

function prepareAccountForTKG () {
    
    prepareAccount || returnOrexit || return 1
    
    acceptBaseImageLicense $AZ_BASE_IMAGE || returnOrexit || return 1


    return 0
}


function createAKSCluster () {


    source $HOME/binaries/scripts/extract-and-take-input.sh

    printf "\n\nDownloading Azure scripts....\n\n"
    $HOME/binaries/scripts/download-common-scripts.sh clouds.azure scripts/clouds/azure
    sleep 2
    printf "DOWNLOAD COMPLETE...\n"
    
    source $HOME/binaries/scripts/clouds/azure/azure.sh
    prepareAccount || returnOrexit || exit 1


    if [ -z "$AZ_TENANT_ID" ] || [ -z "$AZ_APP_ID" ] || [ -z "$AZ_APP_CLIENT_SECRET" ] || [ -z "$AZ_GROUP_NAME" ] || [ -z "$AZ_LOCATION" ] || [ -z "$AZ_AKS_CLUSTER_NAME" ] || [ -z "$AZ_AKS_VM_SIZE" ] || [ -z "$AZ_AKS_NODE_COUNT" ]
    then
        printf "\n\nNo AZ config found.\nGoing to collect from user and save it in .env for future use....\n\n"
        cp $HOME/binaries/templates/az-aks-variables.template /tmp/az-aks-variables.env.tmp || exit 1
        extractVariableAndTakeInput /tmp/az-aks-variables.env.tmp || exit 1
        export $(cat $HOME/.env | xargs)
    fi




    ISAZLOGGEDIN=$(az account show | grep name)
    if [ -z "$ISAZLOGGEDIN" ]
    then
        printf "\n\nlogin to az\n\n"
        if [ -z "$AZ_TENANT_ID" ] || [ -z "$AZ_APP_ID" ] || [ -z "$AZ_APP_CLIENT_SECRET" ]
        then
            printf "\n\naz login\n\n"
            az login
        else
            printf "\n\naz login --service-principal --username $AZ_APP_ID --password $AZ_APP_CLIENT_SECRET --tenant $AZ_TENANT_ID\n\n"
            az login --service-principal --username $AZ_APP_ID --password $AZ_APP_CLIENT_SECRET --tenant $AZ_TENANT_ID
        fi
        printf "\n\nLogged with below details\n"
        az account show
    else
        printf "\n\nAlready logged with below details\n"
        az account show
    fi

    ISAZLOGGEDIN=$(az account show | grep name)
    if [ -z "$ISAZLOGGEDIN" ]
    then
        printf "\nERROR:Login unsuccessfull\n"
        exit 1
    fi

    local isexistsaz=$(az group show --name ${AZ_GROUP_NAME} | jq -r '.id')
    if [[ -z $isexistsaz ]]
    then
        printf "\nResource group not found with name: ${AZ_GROUP_NAME} in location: ${AZ_LOCATION}. Creating new...\n"
        az group create -l ${AZ_LOCATION} -n ${AZ_GROUP_NAME}
    fi

    printf "\nAdd pod security policies support preview (required for learningcenter)\n"
    az extension add --name aks-preview
    az provider register --namespace Microsoft.ContainerService
    az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService
    # Wait until the status is "Registered"
    isregistered='not'
    count=1
    while [[ $isregistered == 'Registered' && $count -lt 15 ]]; do
        printf "\nWaiting for 1m before checking status is 'Registered' for Microsoft.ContainerService/PodSecurityPolicyPreview...(try #$count of 15)\n"
        sleep 1m
        isregistered=$(az feature list  --query "[?contains(name, 'Microsoft.ContainerService/PodSecurityPolicyPreview')].{state:properties.state}" | jq -r '.[] | select(.state == "Registered") | .state')
        ((count=$count+1))
    done

    printf "\nCreate aks cluster in rg:${AZ_GROUP_NAME} name:${AZ_AKS_CLUSTER_NAME} of nodesize:${AZ_AKS_VM_SIZE} with nodecount:${AZ_AKS_NODE_COUNT}\n"
    az aks create --resource-group ${AZ_GROUP_NAME} --name ${AZ_AKS_CLUSTER_NAME} --node-count ${AZ_AKS_NODE_COUNT} --node-vm-size ${AZ_AKS_VM_SIZE} --enable-pod-security-policy --generate-ssh-keys #--node-osdisk-size 500 #--enable-addons monitoring

    printf "\naks cluster get credential. This should create $HOME/.kube/config file...\n"
    az aks get-credentials --resource-group ${AZ_GROUP_NAME} --name ${AZ_AKS_CLUSTER_NAME}

    printf "\ncreating clusterrolebinding:tap-psp-rolebinding --group=system:authenticated --clusterrole=psp:privileged...\n"
    kubectl create clusterrolebinding tap-psp-rolebinding --group=system:authenticated --clusterrole=psp:privileged

    printf "\nCOMPLETE\n\n\n"
}