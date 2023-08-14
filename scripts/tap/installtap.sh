#!/bin/bash

test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

installTap()
{

    local tapValueFile=$1

    printf "\n\n************Checking if TAP marked as deployed**********\n"
    # This logic is flawd. Need to change to something solid
    sleep 1
    
    # UPDATE: 27/07/2023 ---- Blocking the below block. As not I have clarity that below is unnecessary.
    # because whether TAP is installed or not will be checked properly in the "installtapprofile.sh" just before installing TAP.
    # and the env var COMPLETE is unnessary as I have not used it anywhere.
    
    # if [[ -z $INSTALL_TAP_PROFILE || $INSTALL_TAP_PROFILE != 'COMPLETED' ]]
    # then
    #     printf "Checking tap-install in k8s...\n"
    #     local istapinstalled=$(kubectl get packageinstalls.packaging.carvel.dev -n tap-install | grep -w tap)
    #     if [[ -n $istapinstalled ]]
    #     then
    #         printf "Found tap in tap-install ns in the k8s but .env is not marked as complete. Marking as complete...."
    #         sed -i '/INSTALL_TAP_PROFILE/d' $HOME/.env
    #         printf "\nINSTALL_TAP_PROFILE=COMPLETED" >> $HOME/.env
    #         export INSTALL_TAP_PROFILE=COMPLETED
    #         printf "DONE.\n"
    #     else
    #         printf "TAP is not found in the k8s cluster (ns: tap-install is missing or empty).\n\n"
    #         if [[ -z $COMPLETE || $COMPLETE == 'NO' ]]
    #         then
    #             isexistit="n"    
    #         fi
    #     fi
    # fi   

    if [[ -n $INSTALL_TAP_PROFILE && ($INSTALL_TAP_PROFILE == 'COMPLETED' || $INSTALL_TAP_PROFILE == 'TIMEOUT') ]]
    then
        printf "\n\nINSTALL_TAP_PROFILE is marked as $INSTALL_TAP_PROFILE.\n"
        printf "This will attempt to update with TAP value file if Reconciliation Status is Succeeded.\n"
        # UPDATE: 27/07/2023 ---- Blocking the below block. As not I have clarity that below is unnecessary.
        # because whether TAP is installed or not will be checked properly in the "installtapprofile.sh" just before installing TAP.
        # and the env var COMPLETE is unnessary as I have not used it anywhere.
        
        # if [[ -z $COMPLETE || $COMPLETE == 'NO' ]]
        # then
        #     # printf "Checking tap package version..."
        #     # istapversion=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
        #     printf "\n\n.env is not marked as overall completed. Marking as complete...."
        #     sed -i '/COMPLETE/d' $HOME/.env
        #     printf "\nCOMPLETE=YES" >> $HOME/.env
        #     export COMPLETE=YES
        #     printf "DONE.\n\n"
        # fi
    else
        printf "\n\nINSTALL_TAP_PROFILE is NOT marked as COMPLETED.\n"
    fi
    
    # UPDATE: 27/07/2023 ---- Blocking the below block. As not I have clarity that below is unnecessary.

    # if [[ $isexistit == 'y' || $COMPLETE == 'YES' ]]
    # then
    #     printf "${yellowcolor}This installer has detected that installing TAP is marked as COMPLETED in the .env file.${normalcolor}\n"
    #     printf "Performing tanzu package installed get tap -n tap-install...\n"
    #     tanzu package installed get tap -n tap-install
    #     printf "\n\n"
    #     if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    #     then
    #         while true; do
    #             read -p "Would you like to re-deploy tap? [y/n]: " yn
    #             case $yn in
    #                 [Yy]* ) isexistit='n'; printf "you confirmed yes.\n"; break;;
    #                 [Nn]* ) isexistit='y'; printf "You said no.\n"; break;;
    #                 * ) echo "Please answer y or n.";;
    #             esac
    #         done
    #     fi
    # fi
    # sleep 2


    local doinstall=''

    if [[ $INSTALL_TAP_PACKAGE_REPOSITORY != 'COMPLETED' ]]
    then
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            while true; do
                read -p "Confirm if you like to deploy Tanzu Application Platform (TAP) on this k8s cluster now [y/n]: " yn
                case $yn in
                    [Yy]* ) doinstall="y"; printf "\nyou confirmed yes\n"; break;;
                    [Nn]* ) printf "\n\nYou said no.\n"; break;;
                    * ) echo "Please answer y or n.";;
                esac
            done
        else 
            doinstall="y";
        fi
    fi

    if [[ $INSTALL_TAP_PACKAGE_REPOSITORY == 'COMPLETED' ]]
    then
        doinstall="y"
    fi

    if [[ $doinstall == "y" ]] 
    then
        local performinstall=''
        if [[ $INSTALL_TAP_PACKAGE_REPOSITORY == 'COMPLETED' ]]
        then
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                printf "\nFound package repository installation is marked as complete\n"
                while true; do
                    read -p "Do you want to trigger install tap-package-repository again? [y/n]: " yn
                    case $yn in
                        [Yy]* ) performinstall="y"; printf "you confirmed yes\n"; break;;
                        [Nn]* ) performinstall="n";printf "You said no.\n"; break;;
                        * ) echo "Please answer y or n.";;
                    esac
                done
            else
                printf "\n\nTanzu Package Repository deployment is marked as $INSTALL_TAP_PACKAGE_REPOSITORY\n"
                printf "This will SKIP deploying Tanzu Package Repository.\n\n"
                performinstall="n"
            fi
        else
            printf "\n\nTINSTALL_TAP_PACKAGE_REPOSITORY is NOT marked as COMPLETED.\n"
            performinstall='y'
        fi

        printf "\n\n----------Finished Checking---------\n\n\n"
        sleep 2

        if [[ $performinstall == 'y' ]]
        then
            printf "\nAdding TAP package repository.......\n"
            source $HOME/binaries/scripts/tap/installtappackagerepository.sh
            installTapPackageRepository
            printf "\n\n********TAP packages repository add....COMPLETE**********\n\n\n"
        fi
        sleep 3

        performinstall='n'
        if [[ $INSTALL_TAP_PACKAGE_REPOSITORY == 'COMPLETED' ]]
        then
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                while true; do
                    if [[ $INSTALL_TAP_PROFILE == 'COMPLETED' ]]
                    then
                        read -p "Would you like to re-deploy TAP profile now? [y/n]: " yn
                    else
                        read -p "Would you like to deploy TAP profile now? [y/n]: " yn
                    fi
                    
                    case $yn in
                        [Yy]* ) printf "you confirmed yes\n"; performinstall='y'; break;;
                        [Nn]* ) printf "You said no.\n\nExiting...\n\n"; break;;
                        * ) echo "Please answer y or n.\n";;
                    esac
                done
            else                
                performinstall='y'                 
            fi
        fi
        
        if [[ $performinstall == 'y' ]]
        then
            if [[ -n $tapValueFile ]]
            then
                printf "\nApplying TAP values file: $tapValueFile.......\n"
            else
                printf "\nApplying TAP values file.......\n"
            fi
            source $HOME/binaries/scripts/tap/installtapprofile.sh
            installTapProfile $tapValueFile
        fi
        sleep 3

        performinstall='n'
        if [[ $INSTALL_TAP_PROFILE == 'COMPLETED' ]]
        then   
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then         
                while true; do
                    read -p "Would you like to configure developer workspace now? [y/n] " yn
                    case $yn in
                        [Yy]* ) printf "you confirmed yes\n"; performinstall='y'; break;;
                        [Nn]* ) printf "You confirmed no.\n"; break;;
                        * ) echo "Please answer y or n.";
                    esac
                done
            else
                performinstall='y'
            fi
            if [[ $performinstall == 'y' ]]
            then
                printf "\nSetting up developer NS.......\n"
                source $HOME/binaries/scripts/tap/installdevnamespace.sh
                createDevNS $tapValueFile
                printf "\nDeveloper Namespace setup complete...\n"
            fi
        fi  
    fi    
 
    printf "\ninstaller processing completed.\n"
    

}