#!/bin/bash

sourceUrl="https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/"

printf "\nStarting download script...\n"

# if [[ -z $1 && -z $2 ]]
# then
#     printf "\nYou must provide necessary parameters eg: param#1 downloads-bundle-name and param#2 location\nif param#2 is not provide the default location is current directory.\n"
# fi

destinationDir='.'
if [[ -n $2 ]]
then
    destinationDir=$2
fi

param1prompt="scripts download = all"
readarray -t scripts < <(ls -1)
if [[ $1 == 'install-tanzu-framework' ]]
then
    param1prompt="scripts download = $1"
    scripts=("install-tanzu-framework-tarfile.sh")
fi

printf "\nDestinatin DIR = $destinationDir\n"
printf "$param1prompt\n"

if [[ -d $destinationDir ]]
then
    cd $destinationDir
    for i in ${scripts[@]}; do
        printf "\ncurl -L -O $sourceUrl$i"
        curl -L -O $sourceUrl$i
    done
    cd ~
else
    printf "\nERROR: destination DIR does not exists\n"
fi

