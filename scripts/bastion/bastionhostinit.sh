#!/bin/bash

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh
source $HOME/binaries/scripts/install-tanzu-cli.sh

printf "\n${yellowcolor}Installing tanzu on remote...${normalcolor}\n"
installTanzuCLI
printf "\n\n${greencolor}DONE${normalcolor}\n\n\n"
printf "\n\n"

tanzu plugin list

tail -f /dev/null