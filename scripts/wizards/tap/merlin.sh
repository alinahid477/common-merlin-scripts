#!/bin/bash

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/scripts/tap/installtap.sh 

source $HOME/binaries/scripts/tap/installtappackagerepository.sh
source $HOME/binaries/scripts/tap/installtapprofile.sh
source $HOME/binaries/scripts/tap/installdevnamespace.sh



function helpFunction()
{
    printf "\n"
    echo "Usage:"
    echo -e "\t-t | --install-tap no paramater needed. Signals the wizard to start the process for installing TAP for Tanzu Enterprise. Optionally pass values file using -f or --file flag."
    echo -e "\t-r | --install-tap-package-repository no paramater needed. Signals the wizard to start the process for installing package repository for TAP."
    echo -e "\t-p | --install-tap-profile Signals the wizard to launch the UI for user input to take necessary inputs and deploy TAP based on profile curated from user input. Optionally pass profile file using -f or --file flag."
    echo -e "\t-n | --create-developer-namespace signals the wizard create developer namespace."
    echo -e "\t-v | --create-service-account signals the wizard start creating service account."
    echo -e "\t-x | --create-docker-registry-secret signals the wizard start creating docker registry secret."
    echo -e "\t-y | --create-basic-auth-secret signals the wizard start creating basic auth secret."
    echo -e "\t-z | --create-git-ssh-secret signals the wizard start creating git ssh secret."
    echo -e "\t-h | --help"
    printf "\n"
}


unset tapInstall
unset tapPackageRepositoryInstall
unset tapProfileInstall
unset tapDeveloperNamespaceCreate
unset wizardUTILCreateServiceAccount
unset wizardUTILCreateDockerSecret
unset wizardUTILCreateBasicAuthSecret
unset wizardUTILCreateGitSSHSecret
unset argFile
unset ishelp
unset isSkipK8sCheck
# unset adjustContourForValuesFile


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


    # if [[ $adjustContourForValuesFile == 'y' ]]
    # then
    #     unset adjustContourForValuesFile
    #     if [[ -n $file ]]
    #     then
    #         printf "\nAdjusting Contour Block in file: $file\n"
    #         addContourBlockAccordinglyInProfileFile $file            
    #     fi
    #     returnOrexit || return 1
    # fi

    printf "\nThis shouldn't have happened. Embarrasing.\n"
}



output=""

# NEW LOGIC: adjust-contour-for-valuesfile. 19.05.2023
# this is to add contour block for tap-values-file (eg: use nlb for aws)
# the immidiate usecase for this is the webUI. This so that I can call command to add the contour block in the tap-values file so that
#   I can show the updated file in the webUI.
# The values file template in the webUI does not have contour block and need to get that block populated dynamically
#  based on the fact which cluster is it in (eg: is it AWS or Is it something else)


# read the options
TEMP=`getopt -o tarpnkf:i:bvxyzh --long install-tap,install-tap-package-repository,install-tap-profile,create-developer-namespace,configure-kpack,file:,input:,skip-k8s-check,create-service-account,create-docker-registry-secret,create-basic-auth-secret,create-git-ssh-secret,help -n $0 -- "$@"`
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