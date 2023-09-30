#!/bin/bash


test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

source $HOME/binaries/scripts/returnOrexit.sh


installTapPackageRepository()
{
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

    printf "\n\n\n********* Checking pre-requisites *************\n\n\n"
    sleep 1
    if [[ -n $AIRGAP_TAP_PACKAGES_TAR && -f $AIRGAP_TAP_PACKAGES_TAR ]]
    then
        printf "\nAirGap installtion mode detected. Skipping TanzuNet credential..."
    else
        printf "\nChecking TanzuNet authentication presence..."
        if [[ -z $INSTALL_REGISTRY_USERNAME || -z $INSTALL_REGISTRY_PASSWORD ]]
        then
            printf "\nERROR: Tanzu Net username or password missing.\n"
            returnOrexit || return 1
        fi
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
    
    printf "\nPerforming docker login for pvt registry and install registry...\n"
    sleep 2
    # PATCH: Dockerhub is special case
    # This patch is so that 
    local myregistryserver=$PVT_INSTALL_REGISTRY_SERVER
    if [[ -n $PVT_INSTALL_REGISTRY_SERVER && $PVT_INSTALL_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
    then
        myregistryserver="index.docker.io"
    fi

    # UPDATE: 22/9/2023
    # this is for GCR distinction. This is so that we can use keyfile for docker login and tanzu secret create.
    local myregistryservertype=$PVT_INSTALL_REGISTRY_TYPE

    # UPDATE: 6/9/2023
    # Hard coding the below. AS I don't know if having a different name will work or not.
    export PVT_INSTALL_REGISTRY_REPO=tap-packages

    if [[ $INSTALL_FROM_TANZUNET == true || -z $PVT_INSTALL_REGISTRY_SERVER || $myregistryserver == $INSTALL_REGISTRY_HOSTNAME ]]
    then
        printf "\nDetected user input to install directly from TanzuNet: $myregistryserver.\n"
        sleep 2

        export PVT_INSTALL_REGISTRY_SERVER=$INSTALL_REGISTRY_HOSTNAME
        myregistryserver=$INSTALL_REGISTRY_HOSTNAME
        myregistryservertype='tanzunet'
        export PVT_INSTALL_REGISTRY_TYPE=$myregistryservertype
        export PVT_INSTALL_REGISTRY_USERNAME=$INSTALL_REGISTRY_USERNAME
        export PVT_INSTALL_REGISTRY_PASSWORD=$INSTALL_REGISTRY_PASSWORD
        export PVT_INSTALL_REGISTRY_PROJECT=$INSTALL_REGISTRY_PROJECT
        # UPDATE: 6/9/2023
        # modified the env file to reflect INSTALL_REGISTRY_REPO=tap-packages 
        # it shouldn't be INSTALL_REGISTRY_REPO=tanzu-application-platform --> This is wrong. BECAUSE tanzu-application-platform is the projectid in tanzunet harbor
        # hence, the PVT_INSTALL_REGISTRY_REPO=$INSTALL_REGISTRY_REPO means PVT_INSTALL_REGISTRY_REPO=tap-packages ---> which is the repository, NOT projectid.
        # export PVT_INSTALL_REGISTRY_REPO=$INSTALL_REGISTRY_REPO --> I have now hardcoded this value above.
        # If there exist PVT_INSTALL_REGISTRY_PROJECT then we MUST keep it intact (because that's the user input projectid).
        #   and tap-packages repo should go under the projectid.
    elif [[ -z $AIRGAP_TAP_PACKAGES_TAR  ]]
    then
        printf "\ndocker login to TanzuNet: $INSTALL_REGISTRY_HOSTNAME...\n"
        docker login ${INSTALL_REGISTRY_HOSTNAME} -u ${INSTALL_REGISTRY_USERNAME} -p ${INSTALL_REGISTRY_PASSWORD} && printf "DONE.\n"
        sleep 1
    fi
    
    if [[ $myregistryserver == $INSTALL_REGISTRY_HOSTNAME ]]
    then
        printf "\ndocker login to TanzuNet registry: $myregistryserver...\n"
    else
        if [[ -n $PVT_INSTALL_REGISTRY_PROJECT ]]
        then
            printf "\ndocker login to private install registry ${myregistryserver}/$PVT_INSTALL_REGISTRY_PROJECT/${PVT_INSTALL_REGISTRY_REPO}...\n"
        else 
            printf "\ndocker login to private install registry ${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}...\n"
        fi
    fi
    if [[ $myregistryserver == "index.docker.io" ]]
    then
        docker login "https://${myregistryserver}/v1/" -u ${PVT_INSTALL_REGISTRY_USERNAME} -p ${PVT_INSTALL_REGISTRY_PASSWORD} && printf "DONE.\n"
    elif [[ $myregistryservertype == "gcr" || $myregistryservertype == "artifactcr" ]]
    then
        printf "performing docker login using keyfile: $PVT_INSTALL_REGISTRY_PASSWORD...\n"
        cat ${PVT_INSTALL_REGISTRY_PASSWORD} | docker login ${myregistryserver} -u ${PVT_INSTALL_REGISTRY_USERNAME} --password-stdin && printf "DONE.\n"
    else
        docker login ${myregistryserver} -u ${PVT_INSTALL_REGISTRY_USERNAME} -p ${PVT_INSTALL_REGISTRY_PASSWORD} && printf "DONE.\n"
    fi
    
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
            local confirmdialog="Confirm to relocate tap-packages to your own pvt registry ${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}? [y/n]: "
            if [[ -n $PVT_INSTALL_REGISTRY_PROJECT ]]
            then
                confirmdialog="Confirm to relocate tap-packages to your own pvt registry ${myregistryserver}/$PVT_INSTALL_REGISTRY_PROJECT/${PVT_INSTALL_REGISTRY_REPO}? [y/n]: "
            fi
            while true; do
                printf "$confirmdialog"
                read yn
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
    
    export PVT_INSTALL_REGISTRY_TBS_DEPS_REPO=full-deps-package-repo
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

        if [[ -n $AIRGAP_TAP_PACKAGES_TAR ]] 
        then
            printf "\nExecuting imgpkg copy from tar: $AIRGAP_TAP_PACKAGES_TAR...\n"
        else
            printf "\nExecuting imgpkg copy from registry.tanzu.vmware.com to $myregistryserver...\n"
        fi
        printf "\nThis may take few mins (30mins - 40mins depending on your speed of internet and image registries)..\n"
        if [[ $myregistryserver == "index.docker.io" ]]
        then
            $HOME/binaries/scripts/tiktok-progress.sh $$ 7200 "image-relocation" & progressloop_pid=$!
            if [[ -n $AIRGAP_TAP_PACKAGES_TAR && -f $AIRGAP_TAP_PACKAGES_TAR ]]
            then
                imgpkg copy --tar $AIRGAP_TAP_PACKAGES_TAR --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_USERNAME}/${PVT_INSTALL_REGISTRY_REPO} --include-non-distributable-layers -y && printf "\n\nCOPY SUCCESSFULLY COMPLETED.\n\n"
            else
                imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_USERNAME}/${PVT_INSTALL_REGISTRY_REPO} -y && printf "\n\nCOPY SUCCESSFULLY COMPLETED.\n\n";
            fi
            kill "$progressloop_pid" > /dev/null 2>&1 || true
            printf "\n...IMG RELOCATION FINISHED...\n"
            sleep 3
            
            if [[ -n $AIRGAP_TBS_PACKAGES_TAR && -f $AIRGAP_TBS_PACKAGES_TAR ]]
            then
                printf "\nExecuting imgpkg copy from tar: $AIRGAP_TBS_PACKAGES_TAR...\n"
                printf "\nThis may take few mins (30mins - 40mins depending on your speed of internet and image registries)..\n"
                $HOME/binaries/scripts/tiktok-progress.sh $$ 7200 "tbs-dependencies-relocation" & progressloop_pid=$!
                imgpkg copy --tar $AIRGAP_TBS_PACKAGES_TAR --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_USERNAME}/${PVT_INSTALL_REGISTRY_TBS_DEPS_REPO} -y && printf "\n\nCOPY SUCCESSFULLY COMPLETED.\n\n"            
                kill "$progressloop_pid" > /dev/null 2>&1 || true
                printf "\n...IMG RELOCATION FINISHED...\n"
                sleep 3
            fi
        else
            $HOME/binaries/scripts/tiktok-progress.sh $$ 7200 "image-relocation" & progressloop_pid=$!
            # echo "imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo=${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}/tap-packages -y";
            if [[ -n $PVT_INSTALL_REGISTRY_PROJECT ]]
            then
                if [[ -n $AIRGAP_TAP_PACKAGES_TAR && -f $AIRGAP_TAP_PACKAGES_TAR ]]
                then
                    imgpkg copy --tar $AIRGAP_TAP_PACKAGES_TAR --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_PROJECT}/${PVT_INSTALL_REGISTRY_REPO} --include-non-distributable-layers -y && printf "\n\nCOPY SUCCESSFULLY COMPLETE.\n\n";
                else
                    imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_PROJECT}/${PVT_INSTALL_REGISTRY_REPO} -y && printf "\n\nCOPY SUCCESSFULLY COMPLETE.\n\n";
                fi                
            else
                if [[ -n $AIRGAP_TAP_PACKAGES_TAR && -f $AIRGAP_TAP_PACKAGES_TAR ]]
                then
                    imgpkg copy --tar $AIRGAP_TAP_PACKAGES_TAR --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO} --include-non-distributable-layers -y && printf "\n\nCOPY SUCCESSFULLY COMPLETE.\n\n";
                else
                    imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO} -y && printf "\n\nCOPY SUCCESSFULLY COMPLETE.\n\n";
                fi                
            fi            
            kill "$progressloop_pid" > /dev/null 2>&1 || true
            printf "\n....IMG RELOCATION FINISHED...\n"
            sleep 3

            if [[ -n $AIRGAP_TBS_PACKAGES_TAR && -f $AIRGAP_TBS_PACKAGES_TAR ]]
            then
                printf "\nExecuting imgpkg copy from tar: $AIRGAP_TBS_PACKAGES_TAR...\n"
                printf "\nThis may take few mins (30mins - 40mins depending on your speed of internet and image registries)..\n"
                $HOME/binaries/scripts/tiktok-progress.sh $$ 7200 "tbs-dependencies-relocation" & progressloop_pid=$!
                if [[ -n $PVT_INSTALL_REGISTRY_PROJECT ]]
                then
                    imgpkg copy --tar $AIRGAP_TBS_PACKAGES_TAR --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_PROJECT}/${PVT_INSTALL_REGISTRY_TBS_DEPS_REPO} -y && printf "\n\nCOPY SUCCESSFULLY COMPLETED.\n\n"
                else
                    imgpkg copy --tar $AIRGAP_TBS_PACKAGES_TAR --to-repo ${myregistryserver}/${PVT_INSTALL_REGISTRY_TBS_DEPS_REPO} -y && printf "\n\nCOPY SUCCESSFULLY COMPLETED.\n\n"
                fi
                kill "$progressloop_pid" > /dev/null 2>&1 || true
                printf "\n...IMG RELOCATION FINISHED...\n"
                sleep 3
            fi
        fi
    else
        printf "\nSkipping image relocation for this installation\n"
        sleep 1
    fi

    if [[ -z $INSTALL_REGISTRY_CREDENTIALS_NAMESPACE ]]
    then
        export INSTALL_REGISTRY_CREDENTIALS_NAMESPACE="tap-install"
    fi
    printf "\nCreate registry secret (tap-registry) for install registry: ${PVT_INSTALL_REGISTRY_SERVER}...\n"
    local tapregitryserver=$myregistryserver
    if [[ $myregistryserver == "index.docker.io" ]]
    then
        tapregitryserver="https://$myregistryserver/v1/"
    fi

    if [[ $myregistryservertype == "gcr" || $myregistryservertype == "artifactcr" ]]
    then
        printf "Creating secret using keyfile: $PVT_INSTALL_REGISTRY_PASSWORD...\n"
        tanzu secret registry add tap-registry --username ${PVT_INSTALL_REGISTRY_USERNAME} --password "$(cat $PVT_INSTALL_REGISTRY_PASSWORD)" --server ${tapregitryserver} --export-to-all-namespaces --yes --namespace $INSTALL_REGISTRY_CREDENTIALS_NAMESPACE
    else
        tanzu secret registry add tap-registry --username ${PVT_INSTALL_REGISTRY_USERNAME} --password ${PVT_INSTALL_REGISTRY_PASSWORD} --server ${tapregitryserver} --export-to-all-namespaces --yes --namespace $INSTALL_REGISTRY_CREDENTIALS_NAMESPACE
    fi
    
    printf "\n...DONE\n\n"

    local appendForSilentMode=""
    if [[ -n $SILENTMODE && $SILENTMODE == 'YES' ]]
    then
        appendForSilentMode='--yes'
    fi    

    printf "\nCreate tanzu-tap-repository...\n"
    if [[ $myregistryserver == "index.docker.io" ]]
    then
        tanzu package repository add tanzu-tap-repository --url ${myregistryserver}/${PVT_INSTALL_REGISTRY_USERNAME}/${PVT_INSTALL_REGISTRY_REPO}:${TAP_VERSION} --namespace tap-install ${appendForSilentMode}
    else
        if [[ -n $PVT_INSTALL_REGISTRY_PROJECT ]]
        then
            tanzu package repository add tanzu-tap-repository --url ${myregistryserver}/${PVT_INSTALL_REGISTRY_PROJECT}/${PVT_INSTALL_REGISTRY_REPO}:${TAP_VERSION} --namespace tap-install ${appendForSilentMode}
        else
            tanzu package repository add tanzu-tap-repository --url ${myregistryserver}/${PVT_INSTALL_REGISTRY_REPO}:${TAP_VERSION} --namespace tap-install ${appendForSilentMode}
        fi        
    fi
    printf "\nwait 10s before checking tanzu-tap-repository status....\n"
    sleep 10

    
    local count=1
    local checkReconcileStatusForTapRepository=''
    local maxCount=15
    while [[ -z $checkReconcileStatusForTapRepository && $count -lt $maxCount ]]; do
        printf "\nChecking tanzu-tap-repository status...\n"
        checkReconcileStatusForTapRepository=$(tanzu package repository get tanzu-tap-repository --namespace tap-install -o json | jq -r '.[] | .status' || echo error)
        checkReconcileStatusForTapRepository=$(echo "$checkReconcileStatusForTapRepository" | awk '{print tolower($0)}')
        printf "$checkReconcileStatusForTapRepository\n"
        if [[ $checkReconcileStatusForTapRepository == *@("reconciling")* ]]
        then
            printf "Did not get a Reconcile successful status: $checkReconcileStatusForTapRepository\n."
            checkReconcileStatusForTapRepository=''
            printf "wait 2m before checking again ($count out of $maxCount max)...."
            printf "\n.\n"
            ((count=$count+2))
            sleep 2m
        elif [[ $checkReconcileStatusForTapRepository == *@("failed")* ]]
        then
            printf "ERROR! Received FAILED. Received status: $checkReconcileStatusForTapRepository\n."
            checkReconcileStatusForTapRepository=''
            printf "wait 2m before checking again ($count out of $maxCount max)...."
            printf "\n.\n"
            ((count=$count+2))
            sleep 2m
        elif [[ $checkReconcileStatusForTapRepository == *@("succeeded")* ]]
        then
            printf "SUCCESS!! Received status: $checkReconcileStatusForTapRepository\n."
            break
        else
            printf "WARNING!! Received status: $checkReconcileStatusForTapRepository\n."
            checkReconcileStatusForTapRepository=''
            printf "wait 2m before checking again ($count out of $maxCount max)...."
            printf "\n.\n"
            ((count=$count+2))
            sleep 2m
        fi            
    done
    printf "\nwait 1m before displaying tanzu-tap-repository installation status...\n"
    sleep 1m
    tanzu package repository get tanzu-tap-repository --namespace tap-install
    printf "\nDONE\n\n"

    if [[ -z $checkReconcileStatusForTapRepository || $checkReconcileStatusForTapRepository != *@("succeeded")* ]]
    then
        printf "\n\nERROR: tanzu-tap-repository did not install correctly. Stop installation...\n"
        sed -i '/INSTALL_TAP_PACKAGE_REPOSITORY/d' $HOME/.env
        sleep 2
        returnOrexit || return 1
    fi

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
    sleep 3

    if [[ -n $AIRGAP_TBS_PACKAGES_TAR && -f $AIRGAP_TBS_PACKAGES_TAR ]]
    then
        printf "\nDetected full-deps-package-repo to be added to tanzu repository.\nAdding full-deps-package-repo to tanzu package repository...\n"
        if [[ $myregistryserver == "index.docker.io" ]]
        then
            tanzu package repository add full-deps-package-repo --url ${myregistryserver}/${PVT_INSTALL_REGISTRY_USERNAME}/${PVT_INSTALL_REGISTRY_TBS_DEPS_REPO}:${TAP_VERSION} --namespace tap-install
        elif [[ -n $PVT_INSTALL_REGISTRY_PROJECT ]]
        then
            tanzu package repository add full-deps-package-repo --url ${myregistryserver}/${PVT_INSTALL_REGISTRY_PROJECT}/${PVT_INSTALL_REGISTRY_TBS_DEPS_REPO}:${TAP_VERSION} --namespace tap-install
        else
            tanzu package repository add full-deps-package-repo --url ${myregistryserver}/${PVT_INSTALL_REGISTRY_TBS_DEPS_REPO}:${TAP_VERSION} --namespace tap-install
        fi
        printf "\nRepository: full-deps-package-repo add...COMPLETED.\n"
    fi
    printf "\nDONE\n\n"
    sleep 3
    printf "\n\n"
}




