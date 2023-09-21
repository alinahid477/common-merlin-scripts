#!/bin/bash

test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/tap/generate-profile-file.sh

installTapProfile() 
{
    local bluecolor=$(tput setaf 4)
    local normalcolor=$(tput sgr0)
    local profilefilename=$1

    # UPDATE: 25/08/2023
    # Below line is utilised in the Jumpstart to show UNINSTALL TAP option as long as it reaches install profile stage.
    # It is also the initiation of output file.
    echo "OUTPUT#OK" > $HOME/configs/output

    # PATCH: Dockerhub is special case
    # This patch is so that 
    #   tanzu secret registry add registry-credentials --server PVT-REGISTRY-SERVER requires dockerhub to be: https://index.docker.io/v1/
    #   BUT
    #   Apptoolkit.values files AND tap-profile values file expects: index.docker.io.
    # Hence I am using CARTO_CATALOG_PVT_REGISTRY_SERVER for the values file just in case.
    # AND doing the below if block to export (derive) the value of CARTO_CATALOG_PVT_REGISTRY_SERVER just for dockerhub.
    # CARTO_CATALOG_PVT_REGISTRY_SERVER is a fail safe.
    if [[ -n $PVT_INSTALL_REGISTRY_SERVER && $PVT_INSTALL_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
    then
        export CARTO_CATALOG_PVT_REGISTRY_SERVER='index.docker.io'
    fi

    if [[ -z $profilefilename ]]
    then
        export notifyfile=/tmp/merlin-tap-notifyfile
        if [ -f "$notifyfile" ]; then
            rm $notifyfile
        fi
        
        generateProfile
        if [ -f "$notifyfile" ]; then
            profilefilename=$(cat $notifyfile)
            test -f $profilefilename && $HOME/binaries/scripts/tap/adjust-contour-in-values-file.sh $profilefilename || (echo "ERROR: Failed to locate values file" && exit 1)
        fi
    fi
    
    if [[ -n $profilefilename && -f $profilefilename ]]
    then
        unset notifyfile
        export TAP_PROFILE_FILE_NAME=$profilefilename
        sed -i '/TAP_PROFILE_FILE_NAME/d' $HOME/.env
        printf "\nTAP_PROFILE_FILE_NAME=$TAP_PROFILE_FILE_NAME" >> $HOME/.env
        
        local confirmed=''
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then            
            while true; do
                read -p "Review the file and confirm to continue? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                    * ) echo "Please answer y or n.";
                esac
            done
        else
            confirmed='y'
        fi

        if [[ $confirmed == 'n' ]]
        then
            returnOrexit || return 1
        fi

        # UPDATE: 5/9/2023
        # Need profiletype to figure out whether to create few k8s secret or not. Used below. 
        local profiletype='full'
        profiletype=$(cat $profilefilename | grep -w  'profile:')
        profiletype=$(echo "$profiletype" | awk '{print tolower($0)}')

        
        # check if kustomize is already installed by TMC or not. If it is installed exclude package: fluxcd.source.controller.tanzu.vmware.com
        local isExistTMCGitOps=$(kubectl get pods -n tanzu-source-controller --no-headers=true --ignore-not-found=true || true)
        if [[ -n $isExistTMCGitOps ]]
        then
            $HOME/binaries/scripts/tap/adjust-excluded-packages-in-values-file.sh $profilefilename "fluxcd.source.controller.tanzu.vmware.com"
        fi

        # update 10/09/2023
        if [[ -n $METADATA_STORE_STORAGE_CLASS_NAME ]]
        then
            $HOME/binaries/scripts/tap/adjust-storage-class-in-values-file.sh $profilefilename $METADATA_STORE_STORAGE_CLASS_NAME
        fi

        confirmed='n'
        printf "\n\nChecking installed tap package version....."
        local tapPackageVersion=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
        printf "found $tapPackageVersion\n\n"
        if [[ -z $tapPackageVersion ]]
        then
            printf "\n${redcolor}ERROR: package version could not be retrieved.${normalcolor}\n"
            printf "Execute below command manually:\n"
            printf "tanzu package install tap -p tap.tanzu.vmware.com -v {TAP_PACKAGE_VERSION} --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s\n"
            printf "${yellowcolor}Where TAP_PACKAGE_VERSION is the version of the tap.tanzu.vmware.com you want to install${normalcolor}\n"
            returnOrexit || return 1
        else
            if [[ -n $TAP_PACKAGE_VERSION && "$TAP_PACKAGE_VERSION" != "$tapPackageVersion" ]]
            then
                printf "\n${redcolor}WARN: .env variable TAP_PACKAGE_VERSION=$TAP_PACKAGE_VERSION does not match version installed on cluster tapPackageVersion=$tapPackageVersion.${normalcolor}\n"
                if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
                then
                    while true; do
                        read -p "confirm to continue install profile using version $tapPackageVersion? [y/n] " yn
                        case $yn in
                            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; returnOrexit || return 1;;
                            * ) echo "Please answer y or n.";
                        esac
                    done
                else
                    printf "\n${yellowcolor}WARN: Retrieved package version $TAP_PACKAGE_VERSION did not match with provided package version: $tapPackageVersion.${normalcolor}\n"
                    printf "\n${yellowcolor}WARN: continuing install tap-values using provided package version: $TAP_PACKAGE_VERSION.${normalcolor}\n"
                    tapPackageVersion=$TAP_PACKAGE_VERSION
                    confirmed='y'
                fi
            else
                if [[ -n $tapPackageVersion && -n $SILENTMODE && $SILENTMODE == 'YES' ]]
                then
                    printf "\n${yellowcolor}Installing using version: $tapPackageVersion.${normalcolor}\n"
                    confirmed='y'
                else 
                    printf "\n${redcolor}Error: Failed to retrieve Tap Package Version from package repository.\nWill attept to continue from TAP_PACKAGE_VERSION=$TAP_PACKAGE_VERSION${normalcolor}\n"
                    tapPackageVersion=$TAP_PACKAGE_VERSION
                    confirmed='y'
                fi
            fi
        fi

        if [[ $confirmed == 'n' ]]
        then
            returnOrexit || return 1
        fi


        # added 25/04/2023
        # TAP 1.5.0 introduced secretname and secret_namespare is the values file (instead of username and password).
        # This opens up the possibility to create the secret (eg: registry-credential) and refer it in the tap values file by default
        # with the usage of namespace provisioner this secret will also be available in the developer-namespace.
        # hence I can create registry-credential in tap-install namespace now and make it available to all other developer-namespace.

        # UPDATE: 01/09/2023
        #    NOT SURE WHY I CREATED THE BELOW CODE BLOCK. AND WHY IT WORKED IN THE PAST.
        #    As registry-credentials needs to be created regardless.
        # if [[ $tapPackageVersion < 1.5.0 ]]
        # then
        #     if [[ -z $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME ]]
        #     then
        #         export PVT_PROJECT_REGISTRY_CREDENTIALS_NAME="registry-credentials"
        #     fi
        #     local myregistryserver=$PVT_PROJECT_REGISTRY_SERVER
        #     if [[ -n $PVT_PROJECT_REGISTRY_SERVER && $PVT_PROJECT_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
        #     then
        #         myregistryserver="index.docker.io"
        #     fi
        #     if [[ -z $PVT_PROJECT_REGISTRY_CREDENTIALS_NAMESPACE ]]
        #     then
        #         export PVT_PROJECT_REGISTRY_CREDENTIALS_NAMESPACE="tap-install"
        #     fi
        #     tanzu secret registry add $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME --username ${PVT_PROJECT_REGISTRY_USERNAME} --password ${PVT_PROJECT_REGISTRY_PASSWORD} --server ${myregistryserver} --export-to-all-namespaces --yes --namespace $PVT_PROJECT_REGISTRY_CREDENTIALS_NAMESPACE
        # fi

        # UPDATE: 01/09/2023
        #   THE below should be, ie: registry-credentials should be always created regardless of TAP version.
        if [[ -z $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME ]]
        then
            export PVT_PROJECT_REGISTRY_CREDENTIALS_NAME="registry-credentials"
        fi
        local myregistryserver=$PVT_PROJECT_REGISTRY_SERVER
        if [[ -n $PVT_PROJECT_REGISTRY_SERVER && $PVT_PROJECT_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
        then
            myregistryserver="https://index.docker.io/v1/"
        fi
        if [[ -z $PVT_PROJECT_REGISTRY_CREDENTIALS_NAMESPACE ]]
        then
            export PVT_PROJECT_REGISTRY_CREDENTIALS_NAMESPACE="tap-install"
        fi
        printf "\nCreate registry secret ($PVT_PROJECT_REGISTRY_CREDENTIALS_NAME) for accessing registry: $PVT_PROJECT_REGISTRY_SERVER...\n"
        if [[ $PVT_PROJECT_REGISTRY_TYPE == "gcr" || $PVT_PROJECT_REGISTRY_TYPE == "artifactcr" ]]
        then
            printf "Creating secret using keyfile: $PVT_PROJECT_REGISTRY_PASSWORD...\n"
            tanzu secret registry add $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME --username ${PVT_PROJECT_REGISTRY_USERNAME} --password "$(cat $PVT_PROJECT_REGISTRY_PASSWORD)" --server ${myregistryserver} --export-to-all-namespaces --yes --namespace $PVT_PROJECT_REGISTRY_CREDENTIALS_NAMESPACE
        else
            tanzu secret registry add $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME --username ${PVT_PROJECT_REGISTRY_USERNAME} --password ${PVT_PROJECT_REGISTRY_PASSWORD} --server ${myregistryserver} --export-to-all-namespaces --yes --namespace $PVT_PROJECT_REGISTRY_CREDENTIALS_NAMESPACE
        fi
        
        printf "\n...DONE\n\n"
        sleep 5
        
        # UPDATE: 5/9/2023
        # K8s secret for KP and Local Proxy only needs to be created for full, iterate and build profile.
        if [[ $profiletype == *@("full")* || $profiletype == *@("iterate")* || $profiletype == *@("build")* ]]   
        then
            if [[ -z $KP_REGISTRY_SERVER || $KP_REGISTRY_SERVER == $PVT_PROJECT_REGISTRY_SERVER ]]
            then
                if [[ -z $BUILD_SERVICE_REPO && -n $KP_DEFAULT_REPO ]]
                then
                    export BUILD_SERVICE_REPO=$KP_DEFAULT_REPO
                fi
                printf "\n\nIMPORTANT: Same container registry server is used for both Build Service and Workload images. (This is normal)\n"
                printf "    Build Service Registry: $KP_REGISTRY_SERVER\n"
                printf "    Workload: $PVT_PROJECT_REGISTRY_SERVER.\n"
                printf "    If a separate registry for Build Service is required please update the tap values files accordingly and create the an appropriate secret in the K8s cluster accordingly.\n\n\n"
                sleep 3
            elif [[ -n $KP_REGISTRY_SERVER && -n $KP_DEFAULT_REPO && -n $KP_REGISTRY_SECRET_NAME && -n $KP_REGISTRY_SECRET_NAMESPACE && -n $KP_DEFAULT_REPO_USERNAME && -n $KP_DEFAULT_REPO_PASSWORD ]]
            then
                local mykpregistryserver=$KP_REGISTRY_SERVER
                if [[ $KP_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
                then
                    mykpregistryserver="https://index.docker.io/v1/"
                fi
                printf "\nCreate a registry secret ($KP_REGISTRY_SECRET_NAME) for accessing build service registry: $mykpregistryserver/$KP_DEFAULT_REPO...\n"
                if [[ $KP_REGISTRY_TYPE == "gcr" ||  $KP_REGISTRY_TYPE == "artifactcr" ]]
                then
                    printf "Creating secret using keyfile: $KP_DEFAULT_REPO_PASSWORD...\n"
                    tanzu secret registry add $KP_REGISTRY_SECRET_NAME --username ${KP_DEFAULT_REPO_USERNAME} --password "$(cat $KP_DEFAULT_REPO_PASSWORD)" --server ${mykpregistryserver} --yes --namespace $KP_REGISTRY_SECRET_NAMESPACE
                else
                    tanzu secret registry add $KP_REGISTRY_SECRET_NAME --username ${KP_DEFAULT_REPO_USERNAME} --password ${KP_DEFAULT_REPO_PASSWORD} --server ${mykpregistryserver} --yes --namespace $KP_REGISTRY_SECRET_NAMESPACE
                fi
                printf "\n...DONE\n\n"
            else
                printf "\nERROR: Failed to create BuildService credentials.\n"
                sleep 5
            fi


            # UPDATE: 5/09/2023
            # LOCAL SOURCE PROXY
            if [[ $tapPackageVersion < 1.6.0 ]]
            then
                printf "\n\nNOTE: TAP Package version is $tapPackageVersion. Local Source Proxy is only support from 1.6 and above.\n\n"
            else
                if [[ (-z $LOCAL_PROXY_REGISTRY_SERVER || $LOCAL_PROXY_REGISTRY_SERVER == $PVT_PROJECT_REGISTRY_SERVER) && -n $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAME && $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAME != $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME ]]
                then
                    printf "\n\nIMPORTANT: Same container registry server is used for both Workload and Local Source Proxy (This is normal for non-prod environment).\n"
                    printf "    Local Source Proxy Registry: $LOCAL_PROXY_REGISTRY_SERVER\n"
                    printf "    Workload: $PVT_PROJECT_REGISTRY_SERVER\n"
                    printf "    If a separate registry for Local Source Proxy is required please update the tap values files accordingly and create the appropriate secret in the K8s cluster accordingly.\n\n\n"
                fi
                if [[ -n $LOCAL_PROXY_REGISTRY_SERVER && -n $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAME && -n $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAMESPACE && -n $LOCAL_PROXY_REGISTRY_USERNAME && -n $LOCAL_PROXY_REGISTRY_PASSWORD && $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAME != $PVT_PROJECT_REGISTRY_CREDENTIALS_NAME ]]
                then
                    local mylpregistryserver=$LOCAL_PROXY_REGISTRY_SERVER
                    if [[ $LOCAL_PROXY_REGISTRY_SERVER =~ .*"index.docker.io".* ]]
                    then
                        mylpregistryserver="https://index.docker.io/v1/"
                    fi
                    printf "\nCreate a registry secret ($LOCAL_PROXY_REGISTRY_CREDENTIALS_NAME) for accessing local source proxy registry: $mylpregistryserver...\n"
                    if [[ $LOCAL_PROXY_REGISTRY_TYPE == "gcr" || $LOCAL_PROXY_REGISTRY_TYPE == "artifactcr" ]]
                    then
                        printf "Creating secret using keyfile: $LOCAL_PROXY_REGISTRY_PASSWORD...\n"
                        tanzu secret registry add $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAME --username ${LOCAL_PROXY_REGISTRY_USERNAME} --password "$(cat $LOCAL_PROXY_REGISTRY_PASSWORD)" --server ${mylpregistryserver} --yes --namespace $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAMESPACE
                    else
                        tanzu secret registry add $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAME --username ${LOCAL_PROXY_REGISTRY_USERNAME} --password ${LOCAL_PROXY_REGISTRY_PASSWORD} --server ${mylpregistryserver} --yes --namespace $LOCAL_PROXY_REGISTRY_CREDENTIALS_NAMESPACE
                    fi
                    printf "\n...DONE\n\n"
                    sleep 3
                else
                    printf "\nERROR: Failed to create Local Source Proxy registry credentials.\n    Cause: missing required parameters for creating K8s secret OR clashing credential name.\n"
                    sleep 5
                fi                
            fi
            
        fi



        local checkReconcileStatus=''
        if [[ $INSTALL_TAP_PROFILE == 'COMPLETED' || $INSTALL_TAP_PROFILE == 'TIMEOUT' ]]
        then
            printf "\nChecking if tap package already installed in successfull state..."
            checkReconcileStatus=$(tanzu package installed get tap -n tap-install -o json | jq -r '.[] | select(.name == "tap") | .status' || true)
            if [[ -n $checkReconcileStatus ]]
            then
                checkReconcileStatus=$(echo "$checkReconcileStatus" | awk '{print tolower($0)}')
                printf "$checkReconcileStatus\n"
                if [[ $checkReconcileStatus == *@("failed")* ]]
                then
                    printf "Did not get a Reconcile successful. Received status: $checkReconcileStatus\n."
                    printf "Performing update using values-file $profilefilename....\n"
                    tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file $profilefilename -n tap-install
                fi
                if [[ $reconcileStatus == *@("reconciling")* ]]
                then
                    printf "Did not get a Reconcile successful. Received status: $checkReconcileStatus\n."
                    printf "You must wait for the reconcile to finish. OR manually perform tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file $profilefilename -n tap-install"
                fi
                if [[ $checkReconcileStatus == *@("succeeded")* ]]
                then
                    printf "Received status: $checkReconcileStatus\n."
                fi
            else
                printf "NOT FOUND.\n"
            fi
        fi

        if [[ -z $checkReconcileStatus ]]
        then
            printf "\ninstalling tap.tanzu.vmware.com in namespace tap-install.\nThis may take few mins to complete....\n"
            #printf "DEBUG: tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_PACKAGE_VERSION --values-file $profilefilename -n tap-install --poll-interval 5s --poll-timeout 15m0s"

            $HOME/binaries/scripts/tiktok-progress.sh $$ 7200 "tap.tanzu.vmware.com-install" & progressloop_pid=$!
            local isSuccess=$(tanzu package install tap -p tap.tanzu.vmware.com -v $tapPackageVersion --values-file $profilefilename -n tap-install)
            printf "\nStatus from tap.tanzu.vmware.com install...RETRIEVED.\n"
            kill "$progressloop_pid" > /dev/null 2>&1 || true

            if [[ -z $isSuccess ]]
            then
                printf "\nError performing tanzu package install tap -p tap.tanzu.vmware.com -v $tapPackageVersion --values-file $profilefilename -n tap-install\n"
                returnOrexit || return 1
            fi
        fi
        printf "\nwait 1m...\n"
        sleep 1m

        printf "\nCheck installation status....\n"
        # printf "DEBUG: tanzu package installed get tap -n tap-install"
        tanzu package installed get tap -n tap-install

        
        # printf "DEBUG: tanzu package installed list -A"
        local count=1
        local reconcileStatus=''
        local ingressReconcileStatus=''
        local maxCount=120
        while [[ -z $reconcileStatus && $count -lt $maxCount ]]; do
            printf "\nVerify that TAP deployment status...."
            reconcileStatus=$(tanzu package installed get tap -n tap-install -o json | jq -r '.[] | select(.name == "tap") | .status' || echo error)
            reconcileStatus=$(echo "$reconcileStatus" | awk '{print tolower($0)}')
            printf "$reconcileStatus\n"
            if [[ $reconcileStatus == *@("reconciling")* ]]
            then
                printf "Did not get a Reconcile successful. Received status: $reconcileStatus\n."
                reconcileStatus=''
                printf "wait 2m before checking again ($count out of $maxCount max)...."
                printf "\n.\n"
                ((count=$count+2))
                sleep 2m
            elif [[ $reconcileStatus == *@("failed")* ]]
            then
                printf "Did not get a Reconcile successful. Received status: $reconcileStatus\n."
                reconcileStatus=''
                printf "wait 2m before checking again ($count out of $maxCount max)...."
                printf "\n.\n"
                ((count=$count+2))
                sleep 2m
            elif [[ $reconcileStatus == *@("succeeded")* ]]
            then
                printf "Received status: $reconcileStatus\n."
                break
            else
                printf "Received status: $reconcileStatus\n."
                reconcileStatus=''
                printf "wait 2m before checking again ($count out of $maxCount max)...."
                printf "\n.\n"
                ((count=$count+2))
                sleep 2m
            fi            
        done
        printf "\nWait 20s before listing the packages installed....\n"
        sleep 20
        printf "\nList packages status....\n"
        sleep 1
        tanzu package installed list -n tap-install

        confirmed='n'
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            while true; do
                read -p "Please confirm if reconcile for needed packages are successful? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You confirmed no.\n"; break;;
                    * ) echo "Please answer y or n.";
                esac
            done
        else
            sleep 5
            if [[ $reconcileStatus == *@("succeeded")* ]]
            then
                confirmed='y'
                printf "\ntap.tanzu.vmware.com install COMPLETE\n"
            fi            
        fi

        printf "\ntap.tanzu.vmware.com package deployment process...finished.\n\n"
        
        # from TAP 1.4.0 the metadatastore is auto. eg: metadataStoreAutoconfiguration: true # Create a service account, the Kubernetes control plane token and the requisite app_config block to enable communications between Tanzu Application Platform GUI and SCST - Store.
        # hence only do manual SA creattion and token add if it is version 1.3.x or older.
        if [[ $tapPackageVersion < 1.4.0 ]]
        then
            local isexistcat=$(cat $profilefilename | grep -w 'scanning:$')
            if [[ -n $isexistcat ]]
            then
                printf "\nDetected user input for scanning functionlity. Metadata store needs to be wired with TAP-GUI in order for scan result to get displayed in the GUI supply chain."
                printf "\nCreating readonly service account name 'metadata-store-read-client' and rolebindings for it...\n"
                kubectl apply -f $HOME/binaries/templates/tap-metadata-store-readonly-sa.yaml
                printf "\nCreated===\nServiceAccount: metadata-store-read-client in NS: metadata-store\nClusterRoleBinding: metadata-store-ready-only with RoleRef: metadata-store-read-only for SA: metadata-store-read-client\n"
                sleep 1
                printf "\nGetting access token for the above created SA..."
                local METADATA_STORE_ACCESS_TOKEN=$(kubectl get secrets -n metadata-store -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='metadata-store-read-client')].data.token}" | base64 -di)
                if [[ -n $METADATA_STORE_ACCESS_TOKEN ]]
                then
                    printf "OBTAINED METADATA_STORE_ACCESS_TOKEN.\nSee below:\n"
                    echo $METADATA_STORE_ACCESS_TOKEN
                    printf "\n\nReplacing TAPGUI_READONLY_CLIENT_SA_TOKEN in $profilefilename file with the access token...\n"
                    local replaceText='TAPGUI_READONLY_CLIENT_SA_TOKEN'
                    awk -v old=$replaceText -v new="$METADATA_STORE_ACCESS_TOKEN" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $profilefilename > $profilefilename.tmp && mv $profilefilename.tmp $profilefilename
                    sleep 1
                    printf "\n$profilefilename file updated with the access token...\n"
                    sleep 1
                    printf "\nUpdating TAP $TAP_VERSION to reflect this change...\n"
                    tanzu package installed update tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file $profilefilename -n tap-install
                    printf "\nWaiting 20s..."
                    sleep 20
                else
                    printf "\n${redcolor}ERROR: Failed to retrieve metadata store access token. Please maniually update the file: $profilefilename in section tap_gui.app_config.proxy.metadata-store.headers.Authorization ${normalcolor}\n"
                    sleep 1
                fi
                sleep 1
                printf "DONE.\n"
            fi
        fi

        if [[ $confirmed == 'y' ]]
        then
            
            source $HOME/binaries/scripts/tap/extract-tap-ingress.sh
            extractTAPIngress
            # update 8/9/2023
            local isitNodePort=$(cat $HOME/configs/output | grep "GENERATEDNODEPORT")
            if [[ -n $isitNodePort ]]
            then
                printf "\nIMPORTANT: Detected usage of NodePort. No need to change domain name. Assuming user will port forward.\n"
                sleep 5
            else
                updateWithNIPIO $profilefilename $TAP_PACKAGE_VERSION
            fi

            export INSTALL_TAP_PROFILE='COMPLETED'
            sed -i '/INSTALL_TAP_PROFILE/d' $HOME/.env
            printf "\nINSTALL_TAP_PROFILE=COMPLETED\n" >> $HOME/.env
            printf "\n\n********TAP profile deployment....COMPLETE**********\n\n\n" 
            sleep 3
        else
            export INSTALL_TAP_PROFILE='TIMEOUT'
            sed -i '/INSTALL_TAP_PROFILE/d' $HOME/.env
            printf "\nINSTALL_TAP_PROFILE=TIMEOUT\n" >> $HOME/.env
            printf "\n\n********TAP profile deployment....TIMEOUT**********\n" 
            printf "\n\nERROR: tap.tanzu.vmware.com deployment status: $reconcileStatus\nTry re-installing again later.\n"
        fi
    fi
}
