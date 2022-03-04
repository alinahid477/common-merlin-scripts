#!/bin/bash

mkdir logs

if [ ! -f "$HOME/binaries/scripts/install-tanzu-cli.sh" ]
then
    if [[ ! -d  "$HOME/binaries/scripts" ]]
    then
        mkdir -p $HOME/binaries/scripts
    fi
    printf "\n\n************Downloading Common Scripts**************\n\n"
    curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o /tmp/download-common-scripts.sh
    chmod +x /tmp/download-common-scripts.sh
    ./tmp/download-common-scripts.sh all $HOME/binaries/scripts/
    sleep 1
    printf "setting executable permssion common scripts..."    
    ls -l $HOME/binaries/scripts/*.sh | awk '{print $9}' | xargs chmod +x
    printf "COMPLETED"
    printf "\n\n"
fi

printf "\nInstalling tanzu..."
source $HOME/binaries/scripts/install-tanzu-cli.sh
installTanzuCLI
printf "DONE\n\n\n"
printf "\n\n"

tanzu plugin list

tail -f /dev/null