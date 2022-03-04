#!/bin/bash
homepath=$(pwd)
remoteDIR="merlin/merlin-tkg"
remoteDockerName=$3

if [[ -z $remoteDockerName ]]
then
    printf "\nERROR: Remote docker name was not passes. This is required. Will not start remote docker in bastion host\n"
    exit 1
fi

docker login -u $1 -p $2
docker build -f $homepath/$remoteDIR/Dockerfile -t $remoteDockerName $homepath/$remoteDIR/binaries/ # --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g)
printf "\n\n\n***********Strating $remoteDockerName in bastionhost...\n"
docker run -td --rm --net=host -v $homepath/$remoteDIR:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name $remoteDockerName $remoteDockerName
printf "\nDONE...\n"