#!/bin/bash

scripts=("returnOrexit.sh" "contains-element.sh" "extract-and-take-input.sh" "install-tanzu-cli.sh" "init-prechecks.sh" "bastion_host_util.sh" "parse_yaml.sh" "select-from-available-options.sh" "tanzu_connect_management.sh")
sourceUrl="https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/"

printf "\nStarting download script...\n"

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
    scripts=("install-tanzu-framework-tarfile.sh")
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

