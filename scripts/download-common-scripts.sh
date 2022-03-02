#!/bin/bash

sourceUrl="https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts"

printf "\nStarting download script...\n"

# if [[ -z $1 && -z $2 ]]
# then
#     printf "\nYou must provide necessary parameters eg: param#1 downloads-bundle-name and param#2 location\nif param#2 is not provide the default location is current directory.\n"
# fi

downloadFilesList='common'
if [[ -n $1 ]]
then
    downloadFilesList=$1
fi

destinationDir='.'
if [[ -n $2 ]]
then
    destinationDir=$2
fi


readarray -t scripts < <(curl -L $sourceUrl/list.$downloadFilesList)

printf "\nDestinatin DIR = $destinationDir\n"
printf "\nScripts download = $downloadFilesList\n"

if [[ -d $destinationDir ]]
then
    cd $destinationDir
    for i in ${scripts[@]}; do
        printf "\ncurl -L -O $sourceUrl/$i"
        curl -L -O $sourceUrl/$i
    done
    cd ~
else
    printf "\nERROR: destination DIR does not exists\n"
fi

