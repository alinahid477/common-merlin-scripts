#!/bin/bash

sourceUrl="https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main"

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

destinationDir="$HOME/binaries"
if [[ -n $2 ]]
then
    destinationDir=$HOME/binaries/$2
fi


readarray -t scripts < <(curl -L $sourceUrl/list.$downloadFilesList)

printf "\nDestinatin DIR = $destinationDir\n"
printf "\nScripts download = $downloadFilesList\n"

if [[ ! -d $destinationDir ]]
then
    mkdir -p $destinationDir
fi

if [[ -d $destinationDir ]]
then
    cd $destinationDir
    for i in ${scripts[@]}; do
        printf "\ncurl -L -O $sourceUrl/$2/$i"
        curl -L -O $sourceUrl/$2/$i
    done
    printf "\n\nsetting permssions...\n"    
    ls -l *.sh | awk '{print $9}' | xargs chmod +x
    if [[ -f Dockerfile ]]
    then
        ls -l Dockerfile | awk '{print $9}' | xargs chmod +rw
        ls -l Dockerfile | awk '{print $9}' | xargs chmod g+rw
    fi
    cd ~
else
    printf "\nERROR: destination DIR does not exists\n"
fi

