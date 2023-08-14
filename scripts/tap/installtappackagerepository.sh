#!/bin/bash


test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

source $HOME/binaries/scripts/returnOrexit.sh


installTapPackageRepository()
{
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

    printf "\n\n\n********* Checking pre-requisites *************\n\n\n"
    sleep 1
    printf "\nChecking Access to Tanzu Net..."
    if [[ -z $INSTALL_REGISTRY_USERNAME || -z $INSTALL_REGISTRY_PASSWORD ]]
    then
        printf "\nERROR: Tanzu Net username or password missing.\n"
        returnOrexit || return 1
    fi
    sleep 1
    printf "COMPLETED.\n\n"
    # printf "\nChecking Cluster Specific Registry...\n"
    # if [[ -z $PVT_INSTALL_REGISTRY_SERVER || -z $PVT_INSTALL_REGISTRY_USERNAME || -z $PVT_INSTALL_REGISTRY_PASSWORD ]]
    # then
    #     printf "\nERROR: Access information to container registry is missing.\n"
    # fi
    
    local isexistkapp=$(which kapp)
    if [[ -z $isexistkapp ]]
    then
        printf "\nERROR: kapp not found, meaning cluster essential has not been installed.\n"
        returnOrexit || return 1
    fi
    local isexisttanzu=$(which tanzu)
    if [[ -z $isexisttanzu ]]
    then
        printf "\nERROR: tanzu cli not found, meaning it has not been installed.\n"
        returnOrexit || return 1
    fi
        
    if [[ -z $INSTALL_TANZU_CLUSTER_ESSENTIAL || $INSTALL_TANZU_CLUSTER_ESSENTIAL != 'COMPLETED' ]]
    then
        source $HOME/binaries/scripts/install-cluster-essential.sh
        installClusterEssential || true
        local ret=$?
        sleep 5
        if [[ $ret == 1 ]]
        then
            printf "\nERROR: TANZU CLUSTER ESSENTIAL installation failed.\n"
            returnOrexit || return 1
        fi
        printf "\ninstall cluster essential....COMPLETED ($ret)\n"
        sleep 5
    fi
    

    local confirmed=''
    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        while true; do
            read -p "Confirm to install tap-repository? [y/n]: " yn
            case $yn in
                [Yy]* ) confirmed='y'; printf "you confirmed yes\n"; break;;
                [Nn]* ) confirmed='n'; printf "You said no.\n\nExiting...\n\n"; break;;
                * ) echo "Please answer y or n.";;
            esac
        done
    else
        confirmed='y'
    fi

    if [[ $confirmed == 'n' ]]
    then
        printf "\nNot proceed further...\n"
        returnOrexit || return 1
    fi

    sleep 1

    printf "\nChecking K8S_VERSION..."
    # FIX: 07/06/2023 --- psp check still returning error.
    # I have no idea why. Adding this logic to avoid the check psp. SUPERRR WEIRD.
    if [[ -n $K8S_VERSION && $K8S_VERSION < 1.25 ]]
    then
        # FIX: 07/06/2023 --- check psp even before executing 2 psp command.
        # for some reason the 2nd psp command (kubectl get psp | grep -w vmware-system-tmc-privileged) throwing error
        #   only when cluster essential install. VERRRYYY WEIRD. I have no idea why.
        printf "\nChecking if PSP exists..."
        local isexistpsp=$(kubectl get psp || true)
        sleep 1
        if [[ -n $isexistpsp ]]
        then
            printf "PSP FOUND\n"
            printf "\nChecking PSP: vmware-system-privileged and vmware-system-tmc-privileged in the cluster..."
            sleep 1
            # FIX: 07/06/2023 --- the below threw error when run in minikube. weird. dont know why.
            local isvmwarepsp=$(kubectl get psp | grep -w vmware-system-privileged || true)
            sleep 1
            local istmcpsp=$(kubectl get psp | grep -w vmware-system-tmc-privileged || true)
            sleep 1
            if [[ -n $isvmwarepsp || -n $istmcpsp ]]
            then
                printf "FOUND\n"
                printf "\nChecking clusterrolebinding:default-tkg-admin-privileged-binding in the cluster..."
                local isclusterroleexist=$(kubectl get clusterrolebinding -A | grep -w default-tkg-admin-privileged-binding)
                if [[ -z $isclusterroleexist ]]
                then
                    
                    if [[ -n $isvmwarepsp ]]
                    then
                        printf "NOT FOUND. Creating for psp:vmware-system-privileged...."
                        kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
                        printf "clusterrolebinding:default-tkg-admin-privileged-binding....CREATED.\n"
                    fi
                    # if [[ -n $istmcpsp ]]
                    # then
                    #     printf "NOT FOUND. Creating for psp:vmware-system-privileged...."
                    #     kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
                    #     printf "clusterrolebinding:default-tkg-admin-privileged-binding....CREATED.\n"
                    # fi
                else
                    printf "FOUND.\n"
                fi
            fi
        else
            printf "NO PSP\n"
        fi
        printf "\nPSP: COMPLETE"
    else
        printf " > 1.24. PSP check not needed\n"
    fi

    sleep 1
    printf "\nchecking k8s ns for tap-install..."
    local istapinstallns=$(kubectl get ns | grep -w tap-install)
    sleep 1
    if [[ -z $istapinstallns ]]
    then
        printf "NOT FOUND\n"
        printf "\nCreate namespace tap-install in k8s..."
        kubectl create ns tap-install
        sleep 2
        printf "\ncreateNS: tap-install....COMPLETE\n\n"
    else
        printf "FOUND. Skipping creating NS: tap-install.\n"
    fi
    
    printf "\nPerforming docker login for pvt registry and tanzu-net...\n"
    sleep 2
    # PATCH: Dockerhub is special case
    # This patch is so that 
    local myregistryserver=$PVT_INSTALL_REGISTRY_SERVER
    if [[ -n $PVT_INSTALL_REGISTRY_SERVER && $PVT_INSTALL_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
    then
        myregistryserver="index.docker.io"
    fi
    if [[ $INSTALL_FROM_TANZUNET == true || -z $PVT_INSTALL_REGISTRY_SERVER || $myregistryserver == $INSTALL_REGISTRY_HOSTNAME ]]
    then
        export PVT_INSTALL_REGISTRY_SERVER=$INSTALL_REGISTRY_HOSTNAME
        myregistryserver=$INSTALL_REGISTRY_HOSTNAME
        export PVT_INSTALL_REGISTRY_USERNAME=$INSTALL_REGISTRY_USERNAME
        export PVT_INSTALL_REGISTRY_PASSWORD=$INSTALL_REGISTRY_PASSWORD
        export PVT_INSTALL_REGISTRY_REPO=$INSTALL_REGISTRY_REPO
    else
        printf "\ndocker login to registry.tanzu.vmware.com...\n"
        docker login ${INSTALL_REGISTRY_HOSTNAME} -u ${INSTALL_REGISTRY_USERNAME} -p ${INSTALL_REGISTRY_PASSWORD} && printf "DONE.\n"
        sleep 1
    fi
    
    printf "\ndocker login to ${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}...\n"
    docker login ${myregistryserver} -u ${PVT_INSTALL_REGISTRY_USERNAME} -p ${PVT_INSTALL_REGISTRY_PASSWORD} && printf "DONE.\n"
    sleep 2

    confirmed=''
    if [[ $myregistryserver == $INSTALL_REGISTRY_HOSTNAME ]]
    then
        confirmed='n'
        printf "\nInstalling directly from $myregistryserver. No need for image relocation.\n"
        sleep 1
    else
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            while true; do
                read -p "Confirm to relocate tap-packages to your own pvt registry ${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}? [y/n]: " yn
                case $yn in
                    [Yy]* ) confirmed='y'; printf "you confirmed yes\n"; break;;
                    [Nn]* ) confirmed='n'; printf "You said no.\n\nExiting...\n\n"; break;;
                    * ) echo "Please answer y or n.";;
                esac
            done
        else
            if [[ (-z $INSTALL_FROM_TANZUNET || $INSTALL_FROM_TANZUNET == false) && $RELOCATE_TAP_INSTALL_IMAGES_TO_PRIVATE_REGISTRY == true ]]
            then
                confirmed='y'
            fi
        fi
    fi
    

    if [[ $confirmed == 'y' ]]
    then
        printf "\nChecking imgpkg..."
        local isexistimgpkg=$(imgpkg version)
        if [[ -z $isexistimgpkg ]]
        then
            printf "\nERROR: imgpgk is missing. This tool is required for image relocation.\n"
            returnOrexit || return 1
        else
            sleep 1
            printf "FOUND.\n"
        fi
        printf "\nExecuting imgpkg copy from registry.tanzu.vmware.com to $myregistryserver...\n"
        printf "\nThis may take few mins (30mins - 40mins depending on your speed of internet and image registries)..\n"
        if [[ $myregistryserver == "index.docker.io" ]]
        then
            $HOME/binaries/scripts/tiktok-progress.sh $$ 7200 "image-relocation" & progressloop_pid=$!
            imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo=${myregistryserver}/${PVT_INSTALL_REGISTRY_USERNAME} -y && printf "\n\nCOPY SUCCESSFULLY COMPLETE.\n\n";
            printf "\n...IMG RELOCATION FINISHED...\n"
            kill "$progressloop_pid" > /dev/null 2>&1 || true
        else
            $HOME/binaries/scripts/tiktok-progress.sh $$ 7200 "image-relocation" & progressloop_pid=$!
            # echo "imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo=${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}/tap-packages -y";
            imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo=${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}/tap-packages -y && printf "\n\nCOPY SUCCESSFULLY COMPLETE.\n\n";
            printf "\n....IMG RELOCATION FINISHED...\n"
            kill "$progressloop_pid" > /dev/null 2>&1 || true
        fi
    else
        printf "\nSkipping image relocation for this installation\n"
        sleep 1
    fi

    if [[ -z $INSTALL_REGISTRY_CREDENTIALS_NAMESPACE ]]
    then
        export INSTALL_REGISTRY_CREDENTIALS_NAMESPACE="tap-install"
    fi
    printf "\nCreate a registry secret for ${PVT_INSTALL_REGISTRY_SERVER}...\n"
    tanzu secret registry add tap-registry --username ${PVT_INSTALL_REGISTRY_USERNAME} --password ${PVT_INSTALL_REGISTRY_PASSWORD} --server ${myregistryserver} --export-to-all-namespaces --yes --namespace $INSTALL_REGISTRY_CREDENTIALS_NAMESPACE
    printf "\n...COMPLETE\n\n"

    local appendForSilentMode=""
    if [[ -n $SILENTMODE && $SILENTMODE == 'YES' ]]
    then
        appendForSilentMode='--yes'
    fi    

    printf "\nCreate tanzu-tap-repository...\n"
    if [[ $myregistryserver == "index.docker.io" ]]
    then
        tanzu package repository add tanzu-tap-repository --url ${myregistryserver}/${PVT_INSTALL_REGISTRY_USERNAME}:${TAP_VERSION} --namespace tap-install ${appendForSilentMode}
    else
        tanzu package repository add tanzu-tap-repository --url ${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}/tap-packages:${TAP_VERSION} --namespace tap-install ${appendForSilentMode}
    fi

    printf "\nWaiting 2m before checking...\n"
    sleep 2m
    printf "\nChecking tanzu-tap-repository status...\n"
    tanzu package repository get tanzu-tap-repository --namespace tap-install
    printf "\nDONE\n\n"

    printf "Extracting latest tap package version in 10s..."
    sleep 10s
    TAP_PACKAGE_VERSION=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
    printf "$TAP_PACKAGE_VERSION"

    sed -i '/TAP_PACKAGE_VERSION/d' $HOME/.env
    printf "\nTAP_PACKAGE_VERSION=$TAP_PACKAGE_VERSION" >> $HOME/.env
    sleep 1
    sed -i '/INSTALL_TAP_PACKAGE_REPOSITORY/d' $HOME/.env
    printf "\nINSTALL_TAP_PACKAGE_REPOSITORY=COMPLETED\n" >> $HOME/.env
    export INSTALL_TAP_PACKAGE_REPOSITORY=COMPLETED

    printf "\nListing available packages in 20s...\n"
    sleep 20s
    tanzu package available list --namespace tap-install
    printf "\nDONE\n\n"
}




