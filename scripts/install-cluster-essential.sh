#!/bin/bash
export $(cat $HOME/.env | xargs)


installClusterEssential () {

    printf "\nChecking kapp-controller and secretgen-controller presence in the cluster..."
    local isInstallClusterEssential=''
    
    local isKappControllerExist=$(kubectl get pods -A | grep -w kapp-controller)
    local isSecretgenControllerExist=$(kubectl get pods -A | grep -w secretgen-controller)
    
    if [[ -n $isKappControllerExist && -n $isSecretgenControllerExist ]]
    then
        printf "FOUND.\n"
        printf "No need to install cluster-essential.\n"
        isInstallClusterEssential='n'
        if [[ -z $INSTALL_TANZU_CLUSTER_ESSENTIAL ]]
        then
            printf "Found kapp-controller and secretgen-controller in the k8s but .env is not marked as complete. Marking as complete....."
            sed -i '/INSTALL_TANZU_CLUSTER_ESSENTIAL/d' $HOME/.env
            printf "\nINSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED" >> $HOME/.env
            export INSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED
            printf "DONE.\n"
            sleep 2
        fi
        returnOrexit || return 2
    fi

    if [[ -z $isKappControllerExist && -z $isSecretgenControllerExist ]]
    then
        local isInstallClusterEssential='y'
    fi

    printf "\nChecking Tanzu cluster essential binary..."
    sleep 1
    local isinflatedCE='n'
    local DIR="$HOME/tanzu-cluster-essentials"
    if [ -d "$DIR" ]
    then
        if [ "$(ls -A $DIR)" ]; then
            isinflatedCE='y'
            printf "\nFound cluster essential is already inflated in $DIR.\nSkipping further checks.\n"
        fi
    fi
    sleep 1
    if [[ $isinflatedCE == 'n' ]]
    then
        local clusteressentialsbinary=$(ls $HOME/binaries/tanzu-cluster-essentials-linux-amd64*)
        if [[ -z $clusteressentialsbinary ]]
        then
            printf "\nERROR: tanzu-cluster-essentials-linux-amd64-x.x.x.tgz is a required binary for TAP installation.\nYou must place this binary under binaries directory.\n"
            returnOrexit || return 1
        else
            local numberoftarfound=$(find $HOME/binaries/tanzu-cluster-essentials-linux-amd64* -type f -printf "." | wc -c)
            if [[ $numberoftarfound -gt 1 ]]
            then
                printf "\nERROR: More than 1 tanzu-cluster-essentials-linux-amd64-x.x.x.tgz found in the binaries directory.\nOnly 1 is allowed.\n"
                returnOrexit || return 1
            fi
        fi
    fi
    printf "COMPLETED.\n\n"
    sleep 2


    
    DIR="$HOME/tanzu-cluster-essentials"
    if [[ $isinflatedCE == 'n' && -n $clusteressentialsbinary ]]
    then
        printf "\nInflating Tanzu cluster essential...\n"
        sleep 1
        local doinflate='y'

        if [ ! -d "$DIR" ]
        then
            printf "Creating new dir:$DIR..."
            mkdir $HOME/tanzu-cluster-essentials && printf "OK" || printf "FAILED"
            printf "\n"
        else
            printf "\n$DIR already exits...\n"
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                while true; do
                    read -p "Confirm to untar in $DIR [y/n]: " yn
                    case $yn in
                        [Yy]* ) doinflate="y"; printf "\nyou confirmed yes\n"; break;;
                        [Nn]* ) doinflate="n";printf "\n\nYou said no.\n"; break;;
                        * ) echo "Please answer y or n.";;
                    esac
                done
            else
                doinflate="y"
            fi
        fi
        if [[ $doinflate == 'n' ]]
        then
            returnOrexit || return 2;
        fi
        if [ ! -d "$DIR" ]
        then
            returnOrexit || return 1
        fi
        printf "\nExtracting $clusteressentialsbinary in $DIR\n"
        tar -xvf ${clusteressentialsbinary} -C $HOME/tanzu-cluster-essentials/ || returnOrexit
        if [[ $isreturnorexit == 'return' ]]
        then
            printf "\n${redcolor}ERROR: Not proceeding further...${normalcolor}\n"
            return 1
        fi
        printf "$clusteressentialsbinary extracted in $DIR....COMPLETED\n\n"
    fi
    
    
    if [[ -d $DIR ]]
    then
        local isexist=$(kapp version)
        if [[ -z $isexist ]]
        then
            printf "\nLinking kapp.....\n"
            cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp || returnOrexit
            if [[ $isreturnorexit == 'return' ]]
            then
                printf "\n${redcolor}ERRPR: Not proceeding further...${normalcolor}\n"
                returnOrexit || return 1
            fi
            chmod +x /usr/local/bin/kapp || returnOrexit
            if [[ $isreturnorexit == 'return' ]]
            then
                printf "\n${redcolor}ERROR: Not proceeding further...${normalcolor}\n"
                returnOrexit || return 1
            fi
            printf "checking kapp....\n"
            kapp version
        fi

        if [[ -z $INSTALL_TANZU_CLUSTER_ESSENTIAL ]]
        then
            printf "Checking cluster essential in k8s...\n"
            local isclusteressential=$(kubectl get configmaps -n tanzu-cluster-essentials | grep -sw 'kapp-controller')
            if [[ -n $isclusteressential ]]
            then
                printf "Found kapp-controller in the k8s but .env is not marked as complete. Marking as complete....."
                sed -i '/INSTALL_TANZU_CLUSTER_ESSENTIAL/d' $HOME/.env
                printf "\nINSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED" >> $HOME/.env
                export INSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED
                printf "DONE.\n"
            fi
            sleep 2
        fi

        local redeploy='n'
        if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
        then
            if [[ $INSTALL_TANZU_CLUSTER_ESSENTIAL == 'COMPLETED' && $isinflatedCE == 'n' ]]
            then
                printf "${yellowcolor}Tanzu-Cluster-Essential is marked as COMPLETED in the .env.\n"
                printf "However, this installation detected a new inflation of tanzu-cluster-essentials-linux-amd64-x.x.x.tgz in the $DIR.${normalcolor}\n"
                while true; do
                    read -p "Would you like to re-deploy tanzu-cluster-essential? [y/n]: " yn
                    case $yn in
                        [Yy]* ) redeploy='y'; printf "you confirmed yes.\n"; break;;
                        [Nn]* ) redeploy='n'; printf "You said no.\n"; break;;
                        * ) echo "Please answer y or n.";;
                    esac
                done
            fi
        fi
        if [[ $redeploy == 'y' ]]
        then
            printf "\nPerforming kubectl get all in the namespace:tanzu-cluster-essential before re-deploy...\n"
            kubectl get all -n tanzu-cluster-essentials
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                while true; do
                    read -p "Are you sure you want to re-deploy tanzu-cluster-essential? [y/n]: " yn
                    case $yn in
                        [Yy]* ) redeploy='y'; printf "you confirmed yes\n"; break;;
                        [Nn]* ) redeploy='n'; printf "You said no.\n"; break;;
                        * ) echo "Please answer y or n.";;
                    esac
                done
            fi
        fi
        if [[ -z $INSTALL_TANZU_CLUSTER_ESSENTIAL || $redeploy == 'y' ]]
        then
            printf "\nInstalling cluster essential in k8s cluster...\n\n"
            sleep 5
            cd $HOME/tanzu-cluster-essentials
            source ./install.sh --yes
            printf "\nTanzu cluster essential instllation....COMPLETED\n\n"

            sleep 2

            sed -i '/INSTALL_TANZU_CLUSTER_ESSENTIAL/d' $HOME/.env
            printf "\nINSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED" >> $HOME/.env
            export INSTALL_TANZU_CLUSTER_ESSENTIAL=COMPLETED
            sleep 1
        fi
        
    else
        printf "\nWARN: Kapp and cluster-essential could not be installed. Most likely $DIR missing.\n"
    fi 
    
}