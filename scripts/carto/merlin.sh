#!/bin/bash

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

# source $HOME/binaries/wizards/installtceapptoolkit.sh 
source $HOME/binaries/scripts/tap/installtap.sh 

source $HOME/binaries/scripts/tap/installtappackagerepository.sh
source $HOME/binaries/scripts/tap/installtapprofile.sh
source $HOME/binaries/scripts/tap/installdevnamespace.sh

source $HOME/binaries/scripts/kpack/configurekpack.sh
source $HOME/binaries/scripts/carto/carto.sh

function helpFunction()
{
    printf "\n"
    echo "Usage:"
    echo -e "\t-t | --install-tap no paramater needed. Signals the wizard to start the process for installing TAP for Tanzu Enterprise. Optionally pass values file using -f or --file flag."
    # echo -e "\t-a | --install-app-toolkit no paramater needed. Signals the wizard to start the process for installing App Toolkit package for TCE. Optionally pass values file using -f or --file flag."
    echo -e "\t-r | --install-tap-package-repository no paramater needed. Signals the wizard to start the process for installing package repository for TAP."
    echo -e "\t-p | --install-tap-profile Signals the wizard to launch the UI for user input to take necessary inputs and deploy TAP based on profile curated from user input. Optionally pass profile file using -f or --file flag."
    echo -e "\t-n | --create-developer-namespace signals the wizard create developer namespace."
    echo -e "\t-k | --configure-kpack signals the wizard to configure kpack."
    echo -e "\t-c | --configure-carto-templates signals the wizard start creating cartographer templates for supply-chain."
    echo -e "\t-s | --create-carto-supplychain signals the wizard start creating cartographer supply-chain."
    echo -e "\t-d | --create-carto-delivery signals the wizard start creating cartographer delivery (for git-ops)."
    echo -e "\t-v | --create-service-account signals the wizard start creating service account."
    echo -e "\t-x | --create-docker-registry-secret signals the wizard start creating docker registry secret."
    echo -e "\t-y | --create-basic-auth-secret signals the wizard start creating basic auth secret."
    echo -e "\t-z | --create-git-ssh-secret signals the wizard start creating git ssh secret."
    echo -e "\t-h | --help"
    printf "\n"
}


unset tapInstall
unset tceAppToolkitInstall
unset tapPackageRepositoryInstall
unset tapProfileInstall
unset tapDeveloperNamespaceCreate
unset wizardConfigureKpack
unset wizardConfigureCartoTemplates
unset wizardCreateCartoSupplychain
unset wizardCreateCartoDelivery
unset wizardUTILCreateServiceAccount
unset wizardUTILCreateDockerSecret
unset wizardUTILCreateBasicAuthSecret
unset wizardUTILCreateGitSSHSecret
unset argFile
unset ishelp
unset isSkipK8sCheck


function doCheckK8sOnlyOnce()
{
    if [[ ! -f /tmp/checkedConnectedK8s  ]]
    then
        source $HOME/binaries/scripts/init-checkk8s.sh
        echo "y" >> /tmp/checkedConnectedK8s
    fi
}


function executeCommand () {
    
    local file=$1
    local skipK8sTest=$2

    if [[ -z $skipK8sTest || $skipK8sTest != 'y'  ]]
    then
        doCheckK8sOnlyOnce
    fi

    

    if [[ $tapInstall == 'y' ]]
    then
        unset tapInstall
        if [[ -z $file ]]
        then
            installTap
        else
            printf "\nDBG: Argument file: $file\n"
            installTap $file
        fi
        returnOrexit || return 1
    fi
    
    if [[ $tceAppToolkitInstall == 'y' ]]
    then
        unset tceAppToolkitInstall
        if [[ -z $file ]]
        then
            installTCEAppToolkit
        else
            printf "\nDBG: Argument file: $file\n"
            installTCEAppToolkit $file
        fi        
        returnOrexit || return 1
    fi

    if [[ $tapPackageRepositoryInstall == 'y' ]]
    then
        unset tapPackageRepositoryInstall
        installTapPackageRepository    
        returnOrexit || return 1
    fi

    if [[ $tapProfileInstall == 'y' ]]
    then
        unset tapProfileInstall
        if [[ -z $file ]]
        then
            installTapProfile
        else
            installTapProfile $file
        fi
        returnOrexit || return 1
    fi

    if [[ $tapDeveloperNamespaceCreate == 'y' ]]
    then
        unset tapDeveloperNamespaceCreate
        createDevNS
        returnOrexit || return 1
    fi

    if [[ $wizardConfigureKpack == 'y' ]]
    then
        unset wizardConfigureKpack
        startConfigureKpack
        returnOrexit || return 1
    fi

    if [[ $wizardConfigureCartoTemplates == 'y' ]]
    then
        unset wizardConfigureCartoTemplates
        createCartoTemplates
        returnOrexit || return 1
    fi

    if [[ $wizardCreateCartoSupplychain == 'y' ]]
    then
        unset wizardCreateCartoSupplychain
        createSupplyChain
        returnOrexit || return 1
    fi

    if [[ $wizardCreateCartoDelivery == 'y' ]]
    then
        unset wizardCreateCartoDelivery
        createDeliveryBasic
        returnOrexit || return 1
    fi

    if [[ $wizardUTILCreateBasicAuthSecret == 'y' ]]
    then
        unset wizardUTILCreateBasicAuthSecret
        createBasicAuthSecret $HOME/configs
        returnOrexit || return 1
    fi

    if [[ $wizardUTILCreateDockerSecret == 'y' ]]
    then
        unset wizardUTILCreateDockerSecret
        createDockerRegistrySecret
        returnOrexit || return 1
    fi

    if [[ $wizardUTILCreateServiceAccount == 'y' ]]
    then
        unset wizardUTILCreateServiceAccount
        createServiceAccount $HOME/configs
        returnOrexit || return 1
    fi

    if [[ $wizardUTILCreateGitSSHSecret == 'y' ]]
    then
        unset wizardUTILCreateGitSSHSecret
        if [[ -z $argFile ]]
        then
            createGitSSHSecret
        else
            createGitSSHSecret $argFile
        fi
        returnOrexit || return 1
    fi

    printf "\nThis shouldn't have happened. Embarrasing.\n"
}



output=""

# read the options
TEMP=`getopt -o tarpnkf:i:bcsdvxyzh --long install-tap,install-tap-package-repository,install-tap-profile,create-developer-namespace,configure-kpack,file:,input:,skip-k8s-check,configure-carto-templates,create-carto-supplychain,create-carto-delivery,create-service-account,create-docker-registry-secret,create-basic-auth-secret,create-git-ssh-secret,help -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -t | --install-tap )
            case "$2" in
                "" ) tapInstall='y';  shift 2 ;;
                * ) tapInstall='y' ;  shift 1 ;;
            esac ;;
        # -a | --install-app-toolkit )
        #     case "$2" in
        #         "" ) tceAppToolkitInstall='y'; shift 2 ;;
        #         * ) tceAppToolkitInstall='y' ; shift 1 ;;
        #     esac ;;
        -n | --create-developer-namespace )
            case "$2" in
                "" ) tapDeveloperNamespaceCreate='y'; shift 2 ;;
                * ) tapDeveloperNamespaceCreate='y' ; shift 1 ;;
            esac ;;
        -r | --install-tap-package-repository )
            case "$2" in
                "" ) tapPackageRepositoryInstall='y';  shift 2 ;;
                * ) tapPackageRepositoryInstall='y' ;  shift 1 ;;
            esac ;;
        -p | --install-tap-profile )
            case "$2" in
                "" ) tapProfileInstall='y'; shift 2 ;;
                * ) tapProfileInstall='y' ; shift 1 ;;
            esac ;;
        -k | --configure-kpack )
            case "$2" in
                "" ) wizardConfigureKpack='y'; shift 2 ;;
                * ) wizardConfigureKpack='y' ; shift 1 ;;
            esac ;;
        -c | --configure-carto-templates )
            case "$2" in
                "" ) wizardConfigureCartoTemplates='y'; shift 2 ;;
                * ) wizardConfigureCartoTemplates='y' ; shift 1 ;;
            esac ;;
        -s | --create-carto-supplychain )
            case "$2" in
                "" ) wizardCreateCartoSupplychain='y'; shift 2 ;;
                * ) wizardCreateCartoSupplychain='y' ; shift 1 ;;
            esac ;;
        -d | --create-carto-delivery )
            case "$2" in
                "" ) wizardCreateCartoDelivery='y'; shift 2 ;;
                * ) wizardCreateCartoDelivery='y' ; shift 1 ;;
            esac ;;

        -v | --create-service-account )
            case "$2" in
                "" ) wizardUTILCreateServiceAccount='y'; shift 2 ;;
                * ) wizardUTILCreateServiceAccount='y' ; shift 1 ;;
            esac ;;
        -x | --create-docker-registry-secret )
            case "$2" in
                "" ) wizardUTILCreateDockerSecret='y'; shift 2 ;;
                * ) wizardUTILCreateDockerSecret='y' ; shift 1 ;;
            esac ;;
        -y | --create-basic-auth-secret )
            case "$2" in
                "" ) wizardUTILCreateBasicAuthSecret='y'; shift 2 ;;
                * ) wizardUTILCreateBasicAuthSecret='y' ; shift 1 ;;
            esac ;;
        -z | --create-git-ssh-secret )
            case "$2" in
                "" ) wizardUTILCreateGitSSHSecret='y'; shift 2 ;;
                * ) wizardUTILCreateGitSSHSecret='y' ; shift 1 ;;
            esac ;;

        -f | --file )
            case "$2" in
                "" ) argFile=''; shift 2 ;;
                * ) argFile=$2;  shift 2 ;;
            esac ;;
        -i | --input )
            case "$2" in
                "" ) argFile=''; shift 2 ;;
                * ) argFile=$2;  shift 2 ;;
            esac ;;
        -b | --skip-k8s-check )
            case "$2" in
                "" ) isSkipK8sCheck='y'; shift 2 ;;
                * ) isSkipK8sCheck='y';  shift 1 ;;
            esac ;;
        -h | --help ) ishelp='y'; helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done

if [[ $ishelp != 'y' ]]
then
    executeCommand $argFile $isSkipK8sCheck
    unset argFile
    unset isSkipK8sCheck
fi
unset ishelp