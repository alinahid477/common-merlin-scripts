#!/bin/bash

if [[ -n $BASTION_HOST ]]
then
    isidrsaexists=$(ls -l $HOME/.ssh/id_rsa)
    if [[ -n $isidrsaexists ]]
    then
        chmod 600 $HOME/.ssh/id_rsa 
        isrsacommented=$(cat $HOME/Dockerfile | grep '#\s*COPY .ssh/id_rsa $HOME/.ssh/')
        if [[ -n $isrsacommented ]]
        then
            printf "\n\nBoth id_rsa file and bastion host input found...\n"
            printf "Adjusting the dockerfile to include id_rsa...\n"
            
            sed -i '/COPY .ssh\/id_rsa \/root\/.ssh\//s/^# //' $HOME/Dockerfile
            sed -i '/RUN chmod 600 \/root\/.ssh\/id_rsa/s/^# //' $HOME/Dockerfile

            printf "\n\nDockerfile is now adjusted with id_rsa.\n\n"
            printf "\n\nPlease rebuild the docker image and run again (or ./start.sh tbs forcebuild).\n\n"
            exit 1
        fi
    else
        printf "\nERROR: Bastion host input provided but no id_rsa present in .ssh directory.\n"
        printf "You must place the private key called \"id_rsa\" in .ssh directory and add the public key to the bastion host server.\n"
        printf "exit 1...\n"
        exit 1
    fi
fi

if [[ -n $TMC_API_TOKEN ]]
then
    printf "\nChecking TMC cli...\n"
    ISTMCEXISTS=$(tmc --help)
    sleep 1
    if [ -z "$ISTMCEXISTS" ]
    then
        printf "\n\ntmc command does not exist.\n\n"
        printf "\n\nChecking for binary presence...\n\n"
        IS_TMC_BINARY_EXISTS=$(ls $HOME/binaries/ | grep tmc)
        sleep 2
        if [ -z "$IS_TMC_BINARY_EXISTS" ]
        then
            printf "\n\nBinary does not exist in $HOME/binaries directory.\n"
            printf "\nIf you like to access k8s cluster using TMC then please download tmc binary from https://{orgname}.tmc.cloud.vmware.com/clidownload and place in the $HOME/binaries directory.\n"
            printf "\nAfter you have placed the binary file you can, additionally, uncomment the tmc relevant in the Dockerfile.\n\n"
            printf "\n\nERROR: TMC_API_TOKEN specified but TMC binary is not present in binaries directory.\nExiting...\n\n"
            exit 1
        else
            printf "\n\nTMC binary found...\n"
            printf "\n\nAdjusting Dockerfile\n"
            sed -i '/COPY binaries\/tmc \/usr\/local\/bin\//s/^# //' $HOME/Dockerfile
            sed -i '/RUN chmod +x \/usr\/local\/bin\/tmc/s/^# //' $HOME/Dockerfile
            sleep 2
            printf "\nDONE..\n"
            printf "\n\nPlease build this docker container again and run.\nor ./start.sh merlin-tap forcebuild\n"
            exit 1
        fi
    else
        printf "TMC CLI Found.\n\n WARN: Deprication warning: TMC CLI will soon be deprecated."
    fi
fi