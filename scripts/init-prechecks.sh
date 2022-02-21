#!/bin/bash

if [[ -n $BASTION_HOST ]]
then
    isexists=$(ls -l $HOME/.ssh/id_rsa)
    if [[ -n $isexists ]]
    then
        chmod 600 $HOME/.ssh/id_rsa 
        isrsacommented=$(cat ~/Dockerfile | grep '#\s*COPY .ssh/id_rsa $HOME/.ssh/')
        if [[ -n $isrsacommented ]]
        then
            printf "\n\nBoth id_rsa file and bastion host input found...\n"
            printf "Adjusting the dockerfile to include id_rsa...\n"
            
            sed -i '/COPY .ssh\/id_rsa \/root\/.ssh\//s/^# //' ~/Dockerfile
            sed -i '/RUN chmod 600 \/root\/.ssh\/id_rsa/s/^# //' ~/Dockerfile

            printf "\n\nDockerfile is now adjusted with id_rsa.\n\n"
            printf "\n\nPlease rebuild the docker image and run again (or ./start.sh tbs forcebuild).\n\n"
            exit 1
        fi
    else
        printf "\nERROR: Bastion host input provided but no id_rsa present in .ssh directory.\n"
        printf "You must place the private key called \"id_rsa\" in .ssh directory and add the public key to the bastion host server.\n"
        printf "exit 1...\n"
        exit
    fi
fi