#!/bin/bash

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh
source $HOME/binaries/scripts/install-tanzu-cli.sh

rm $HOME/COMPLTETED_TANZU_INSTALLATION

printf "\n${yellowcolor}Installing tanzu on remote...${normalcolor}\n"
installTanzuCLI
printf "\n\n${greencolor}DONE${normalcolor}\n\n\n"
printf "\n\n"

tanzu plugin list

printf "COMPLTETED" > $HOME/COMPLTETED_TANZU_INSTALLATION

tail -f /dev/null