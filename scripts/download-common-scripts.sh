#!/bin/bash

scripts=("contains-element.sh" "extract-and-take-input.sh" "install-tanzu-framework.sh" "init-prechecks.sh")
sourceUrl="https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/"

echo "Starting download script..."




if [[ -z $1 && -z $2 ]]
then
    printf "\nYou must provide necessary parameters eg: param#1 downloads-bundle-name and param#2 location\nif param#2 is not provide the default location is current directory.\n"
fi

destinationDir='.'
if [[ -n $2 ]]
then
    destinationDir=$2
fi

if [[ $1 == 'install-tanzu-framework' ]]
then
    scripts=("install-tanzu-framework.sh")
fi

printf "\nDestinatin DIR: $destinationDir\n"

if [[ -d $destinationDir ]]
then
    cd $destinationDir
    for i in ${scripts[@]}; do
        printf "\ncurl -L -O $sourceUrl$i"
        curl -L -O $sourceUrl$i
    done
    cd ~
fi

