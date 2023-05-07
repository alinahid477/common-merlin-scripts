#!/bin/bash

#### USAGE ####
# $HOME/binaries/scripts/download-common-scripts.sh list.{name-of-the-list-file} {sourceDir or readDir} {destinationDie or writeDir} 
# OR
# $HOME/binaries/scripts/download-common-scripts.sh list.{name-of-the-list-file} {sourceDir or readDir} 
# ---- in this case the sourceDir and destinationDir is the same.
###############



baseUrl="https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main"

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

sourceUrlDir="$baseUrl/scripts"
destinationDir="$HOME/binaries"
if [[ -n $2 && -n $3 ]]
then
    # both sourceDir and destinationDir is present
    sourceUrlDir=$baseUrl/$2
    if [[ $3 == /* ]]
    then
        # this means the destinationDir is an absolute path. eg: /tmp/somedir
        destinationDir=$3
    else
        destinationDir=$HOME/binaries/$3
    fi
    
elif [[ -n $2 ]]
then
    # only destinationDir is present
    sourceUrlDir=$baseUrl/$2
    destinationDir=$HOME/binaries/$2  
fi



readarray -t scripts < <(curl -L $baseUrl/list.$downloadFilesList)

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
        printf "\nget: $sourceUrlDir/$i"
        curl -L -O $sourceUrlDir/$i
    done
    printf "\n\nsetting permssions...\n" 
    if [[ ls *.sh &>/dev/null ]]
    then
        ls -l *.sh | awk '{print $9}' | xargs chmod +x
    fi
    if [[ ls *.template &>/dev/null ]]
    then
        ls -l *.template | awk '{print $9}' | xargs chmod +rw
    fi
    if [[ ls *.json &>/dev/null ]]
    then
        ls -l *.json | awk '{print $9}' | xargs chmod +rw
    fi
    if [[ ls *.yaml &>/dev/null ]]
    then
        ls -l *.yaml | awk '{print $9}' | xargs chmod +rw
    fi    
    
    if [[ -f Dockerfile ]]
    then
        ls -l Dockerfile | awk '{print $9}' | xargs chmod +rw
        ls -l Dockerfile | awk '{print $9}' | xargs chmod g+rw
    fi
    cd ~
else
    printf "\nERROR: destination DIR does not exists\n"
fi

