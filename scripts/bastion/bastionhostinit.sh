#!/bin/bash

mkdir logs

if [[ ! -f "$HOME/binaries/scripts/install-tanzu-cli.sh" || ! -f "$HOME/binaries/scripts/returnOrexit.sh" ]]
then
    if [[ ! -d  "$HOME/binaries/scripts" ]]
    then
        mkdir -p $HOME/binaries/scripts
    fi
    printf "\n\n************Downloading Scripts**************\n\n"
    curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o $HOME/binaries/scripts/download-common-scripts.sh
    chmod +x $HOME/binaries/scripts/download-common-scripts.sh
    $HOME/binaries/scripts/download-common-scripts.sh tanzucli scripts
    sleep 1
    printf "\n\n\n///////////// COMPLETED //////////////////\n\n\n"
    printf "\n\n"
fi

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

printf "\nInstalling tanzu..."
source $HOME/binaries/scripts/install-tanzu-cli.sh
installTanzuCLI
printf "DONE\n\n\n"
printf "\n\n"

tanzu plugin list

tail -f /dev/null