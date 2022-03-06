#!/bin/bash
export $(cat /root/.env | xargs)

remoteDIR="~/merlin/merlin-tkg"
remoteDockerName="merlin-tkg-remote"
localBastionDIR=$HOME/binaries/scripts/bastion
localDockerContextName="merlin-bastion-docker-tkg"
clusterEndpointsVariableName='TKG_CLUSTER_ENDPOINTS'

source $HOME/binaries/scripts/bastion_host_util.sh



function prechecks () {
    printf "\n\n\n*********performing prerequisites checks************\n\n\n"

    local configfile=$1
    printf "checking presence of tkg config file $configfile...."
    
    local isexist=$(ls -l $configfile)
    if [[ ! -f $configfile ]]
    then
        printf "\n${redcolor}ERROR: config file missing...${normalcolor}\n"
        returnOrexit || return 1
    fi
    printf "FOUND\n"

    printf "checking presence of $HOME/.ssh/id_rsa...."
    if [[ ! -f $HOME/.ssh/id_rsa ]]
    then
        printf "\n${redcolor}ERROR: Failed. id_rsa file must exist in .ssh directory..."
        printf "\nPlease ensure to place id_rsa file in .ssh directory and the id_rsa.pub in .ssh of $BASTION_USERNAME@$BASTION_HOST${normalcolor}\n"
        returnOrexit || return 1
    fi
    printf "FOUND\n"

    printf "checking environment variable MANAGEMENT_CLUSTER_ENDPOINTS...."
    if [[ -z $MANAGEMENT_CLUSTER_ENDPOINTS ]]
    then
        printf "\n${redcolor}ERROR: bastion host detected BUT MANAGEMENT_CLUSTER_ENDPOINTS is missing from .env file..."
        printf "\nPlease add MANAGEMENT_CLUSTER_ENDPOINTS in the .env (format: 192.168.220.2:6443) file and try again...${normalcolor}\n"
        returnOrexit || return 1
    fi
    printf "FOUND\n"

    printf "checking docker login information in environment variable called DOCKERHUB_USERNAME and DOCKERHUB_PASSWORD...."
    if [[ -z $DOCKERHUB_USERNAME || -z $DOCKERHUB_PASSWORD ]]
    then
        printf "\nERROR: Failed. docker hun username and password missing in env variable..."
        printf "\nPlease ensure DOCKERHUB_USERNAME and DOCKERHUB_PASSWORD in .env file"
        returnOrexit || return 1
    fi
    printf "FOUND\n"

    printf "Checking Docker on $BASTION_USERNAME@$BASTION_HOST..."
    isexist=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'docker --version')
    if [[ -z $isexist ]]
    then
        printf "\n${redcolor}ERROR: Failed. Docker not installed on bastion host..."
        printf "\nPlease install docker on host $BASTION_HOST to continue...${normalcolor}\n"
        returnOrexit || return 1
    else
        printf "FOUND.\nDetails: $isexist\n"
    fi

    printf "Checking python3 on $BASTION_USERNAME@$BASTION_HOST...."
    isexist=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'python3 --version')
    if [[ -z $isexist ]]
    then
        printf "${yellowcolor}python3 not found.\nchecking python on $BASTION_USERNAME@$BASTION_HOST....${normalcolor}"
        isexist=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'python3 --version')
        if [[ -z $isexist ]]
        then
            printf "\n${redcolor}ERROR: Failed. Python not installed on bastion host..."
            printf "\nPlease install Python on host $BASTION_HOST to continue...${normalcolor}"
            returnOrexit || return 1
        else
            printf "FOUND.\nDetails: $isexist\n"
        fi
    else
        printf "FOUND\nDetails: $isexist\n"
    fi

    return 0
}




function prepareRemote () {
    local configfile=$1
    if [[ ! -f $configfile ]]
    then
        printf "\n${redcolor}ERROR: config file missing...${normalcolor}\n"
        returnOrexit || return 1
    fi

    printf "\n\n\n********Preparing $BASTION_USERNAME@$BASTION_HOST for merlin*********\n\n\n"

    isexist=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls -l '$remoteDIR)
    if [[ -z $isexist ]]
    then
        printf "\nCreating structual directories 'merlin' in $BASTION_USERNAME@$BASTION_HOST home dir"
        ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'mkdir -p '$remoteDIR'/binaries' || returnOrexit || return 1
        ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'mkdir -p '$remoteDIR'/.ssh' || returnOrexit || return 1
    fi
    isexist=$(ssh -i ~/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls -l '$remoteDIR'/workload-clusters')
    if [[ -z $isexist ]]
    then
        printf "\nCreating directory '$remoteDIR'/workload-clusters' in $BASTION_USERNAME@$BASTION_HOST home dir"
        ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'mkdir -p '$remoteDIR'/workload-clusters; mkdir -p '$remoteDIR'/.config/tanzu; mkdir -p '$remoteDIR'/.kube-tkg; mkdir -p '$remoteDIR'/.kube' || returnOrexit || return 1
    fi


    printf "\nGetting remote files list from $BASTION_USERNAME@$BASTION_HOST\n"
    ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls '$remoteDIR'/binaries/' > /tmp/bastionhostbinaries.txt || returnOrexit || return 1
    ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls '$remoteDIR'/' > /tmp/bastionhosthomefiles.txt || returnOrexit || return 1
    ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls '$remoteDIR'/.ssh/' >> /tmp/bastionhosthomefiles.txt || returnOrexit || return 1
    ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls '$remoteDIR'/.config/tanzu/' >> /tmp/bastionhosthomefiles.txt || printf "....ingnoring error as file already exists"
    ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls '$remoteDIR'/.kube-tkg/' >> /tmp/bastionhosthomefiles.txt || printf "....ingnoring error as file already exists"



    # default look for: tanzu tap cli
    tarfilenamingpattern="tanzu-framework-linux-amd64*"
    tanzuclibinary=$(ls $HOME/binaries/$tarfilenamingpattern)
    if [[ -z $tanzuclibinary ]]
    then
        # fallback look for: tanzu ent
        tarfilenamingpattern="tanzu-cli-*.tar.*"
        tanzuclibinary=$(ls $HOME/binaries/$tarfilenamingpattern)
    fi
    if [[ -z $tanzuclibinary ]]
    then
        # fallback look for: tanzu tce
        tarfilenamingpattern="tce-*.tar.*"
        tanzuclibinary=$(ls $HOME/binaries/$tarfilenamingpattern)
    fi
    tanzuclibinaryfilename=$(echo ${tanzuclibinary##*/})
    isexist=$(cat /tmp/bastionhostbinaries.txt | grep -w "^${tanzuclibinaryfilename}$")
    if [[ -z $isexist ]]
    then
        printf "\nUploading $tanzuclibinary\n"
        scp $tanzuclibinary $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/binaries/ || returnOrexit || return 1
    fi

    
    
    printf "\nUploading $configfile\n"
    scp $configfile $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/workload-clusters/ || returnOrexit || return 1

    printf "\nChecking remote $remoteDIR/.config/tanzu/config.yaml..."
    isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "config.yaml$")
    if [[ -z $isexist ]]
    then
        printf "\nUploading $HOME/.config/tanzu/config.yaml\n"
        scp $HOME/.config/tanzu/config.yaml $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/.config/tanzu/ || returnOrexit || return 1
    fi

    printf "\nChecking remote $remoteDIR/.kube-tkg/config..."
    isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "config$")
    if [[ -z $isexist ]]
    then
        if [[ ! -f $HOME/.kube-tkg/config.remote ]]
        then
            printf "\nAdjusting $HOME/.kube-tkg/config for remote..."
            modifyConfigFileForTunnel $HOME/.kube-tkg/config $HOME/.kube-tkg/config.remote $MANAGEMENT_CLUSTER_ENDPOINTS || returnOrexit || return 1
        fi
        
        printf "\nUploading .kube-tkg/config and .kube/config\n"
        scp $HOME/.kube-tkg/config.remote $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/.kube-tkg/config || printf "....ignoring, file already exists\n" && printf "....COMPLETED\n"
        scp $HOME/.kube-tkg/config.remote $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/.kube/config || printf "....ignoring, file already exists\n" && printf "....COMPLETED\n"
    fi



    isexist=$(cat /tmp/bastionhostbinaries.txt | grep -w "bastionhostinit.sh$")
    if [[ -z $isexist ]]
    then
        printf "\nUploading bastionhostinit.sh\n"
        scp $localBastionDIR/bastionhostinit.sh $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/binaries/ || returnOrexit || return 1
    fi

    isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "bastionhostrun.sh$")
    if [[ -z $isexist ]]
    then
        printf "\nUploading bastionhostrun.sh\n"
        scp $localBastionDIR/bastionhostrun.sh $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/ || returnOrexit || return 1
    fi

    isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "Dockerfile$")
    if [[ -z $isexist ]]
    then
        printf "\nUploading Dockerfile\n"
        scp $localBastionDIR/Dockerfile $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/ || returnOrexit || return 1
    fi

    isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "dockerignore$")
    if [[ -z $isexist ]]
    then
        printf "\nUploading .dockerignore\n"
        scp $HOME/.dockerignore $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/ || returnOrexit || return 1
    fi

    isexist=$(ls ~/.ssh/tkg_rsa)
    isexistidrsa=$(cat /tmp/bastionhosthomefiles.txt | grep -w "id_rsa$")
    if [[ -n $isexist && -z $isexistidrsa ]]
    then
        printf "\nUploading .ssh/tkg_rsa\n"
        scp $HOME/.ssh/tkg_rsa $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/.ssh/id_rsa || returnOrexit || return 1
    fi


    return 0
}






function startTKGCreate () {
    local configfile=$1
    if [[ ! -f $configfile ]]
    then
        printf "\n${redcolor}ERROR: config file missing...${normalcolor}\n"
        returnOrexit || return 1
    fi
    
    
    printf "\n\n\n**********Starting remote docker with tanzu cli...*********\n\n\n"
    


    isexist=$(docker context ls | grep "^$localDockerContextName")
    if [[ -z $isexist ]]
    then
        printf "\nCreating remote context $localDockerContextName..."
        docker context create $localDockerContextName  --docker "host=ssh://$BASTION_USERNAME@$BASTION_HOST" || returnOrexit || return 1
        printf "COMPLETED\n"
    fi
    

    printf "\nUsing remote context $localDockerContextName..."
    export DOCKER_CONTEXT=$localDockerContextName
    printf "COMPLETED\n"

    printf "\nWaiting 3s before checking remote container...\n"
    sleep 3

    printf "\nChecking remote context...\n"
    docker ps
    isexist=$(docker ps --filter "name=$remoteDockerName" --format "{{.Names}}")
    if [[ -z $isexist ]]
    then
        # unset DOCKER_CONTEXT

        printf "\n${yellowcolor}No docker name $remoteDockerName running on bastion host...starting docker $remoteDockerName....${normalcolor}\n"
        ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'chmod +x '$remoteDIR'/bastionhostrun.sh && '$remoteDIR'/bastionhostrun.sh '$DOCKERHUB_USERNAME $DOCKERHUB_PASSWORD $remoteDockerName
        
        count=1
        while [[ -z $isexist && $count -lt 4 ]]; do
            printf "\nContainer not running... Retrying in 5s"
            sleep 5
            isexist=$(docker ps --filter "name=$remoteDockerName" --format "{{.Names}}")
            ((count=count+1))
        done
        if [[ -z $isexist ]]
        then
            printf "\n${redcolor}ERROR: Remote container $remoteDockerName not running."
            printf "\nUnable to proceed further. Please check merling directory in your bastion host.${normalcolor}\n"
            returnOrexit || return 1
        fi
    else
        printf "\n${yellowcolor}Docker $remoteDockerName already running. Going to reuse....${normalcolor}\n"
    fi

    # printf "\nSwitching to remote context again $localDockerContextName..."
    # export DOCKER_CONTEXT=$localDockerContextName
    # printf "COMPLETED\n"

    # while true; do
    #     read -p "Did the above command ran successfully? Confirm to continue? [yn] " yn
    #     case $yn in
    #         [Yy]* ) printf "\nyou confirmed yes\n"; break;;
    #         [Nn]* ) printf "\nyou said no\n"; returnOrexit || return 1;;
    #         * ) printf "${redcolor}Please answer y when you are ready.${normalcolor}\n";;
    #     esac
    # done


    printf "\nPerforming ssh-add..."
    docker exec -idt $remoteDockerName bash -c "cd ~ ; ssh-add ~/.ssh/id_rsa" || returnOrexit || return 1
    printf "COMPLETED\n"

    printf "\nchecking for cluster plugin....\n"
    local x=$(docker exec -it $remoteDockerName bash -c "tanzu cluster --help")
    if [[ -z $x || $x == *@("unknown command")* ]]
    then
        printf "\n${yellowcoloe}Cluster plugin not found....installing....${normalcolor}\n"
        docker exec -it $remoteDockerName bash -c "tanzu plugin install cluster"
        printf "\nDONE.\n"
    fi


    printf "\n${yellowcolor}Starting tanzu cluster create in remote context...${normalcolor}"
    docker exec -it $remoteDockerName bash -c "cd ~ ; tanzu cluster create  --file $configfile -v 9"
    printf "COMPLETED\n"

    
    printf "\n${greencolor}==> TGK cluster deployed -->> DONE.${normalcolor}\n"


    
    local confirmation='y'
    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        while true; do
            read -p "Confirm to continue [yn]? " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) confirmation='n'; printf "\nyou confirmed no\n"; break;;
                * ) printf "${redcolor}Please answer y when you are ready.${normalcolor}\n";;
            esac
        done
    else
        printf "\nGoing to wait for 2s\n"
        sleep 2
    fi
    unset DOCKER_CONTEXT
    if [[ $confirmation == 'n' ]]
    then
        returnOrexit || return 1
    fi

    return 0
}



function downloadTKGFiles () {

    local configfile=$1

    if [[ -z $configfile || ! -f $configfile ]]
    then
        printf "\n${redcolor}ERROR: configfile not supplied...${normalcolor}\n"
        returnOrexit || return 1
    fi

    local clusterName=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="CLUSTER_NAME"{print $2}' | xargs)


    local kubeconfigfile="$HOME/.kube/config"
    printf "\n${yellowcolor}Getting cluster info...${normalcolor}\n"
    tanzu cluster kubeconfig get $clusterName --admin
    printf "\n${greencolor}Cluster info now saved in $kubeconfigfile.${normalcolor}\n\n\n" 

    printf "\n${yellowcolor}Adjusting for bastion host...${normalcolor}\n"
    create_bastion_tunnel_from_kubeconfig $kubeconfigfile $clusterEndpointsVariableName || returnOrexit || return 1
    printf "${yellowcolor}==>Adjusting for bastion host...COMPLETED${normalcolor}\n"
    printf "\nConnected TKG cluster\n"
    kubectl get ns
    
    return 0
}



function cleanBastion () {

    local configfile=$1
    if [[ ! -f $configfile ]]
    then
        printf "\n${redcolor}ERROR: config file missing...${normalcolor}\n"
        returnOrexit || return 1
    fi
    local clusterName=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="CLUSTER_NAME"{print $2}' | xargs)

    printf "\n\n\n***********crealing bastion host...***********\n\n\n"

    printf "\nSwitching to remote context $localDockerContextName..."
    export DOCKER_CONTEXT=$localDockerContextName
    printf "COMPLETED\n"

    local error=''

    printf "\n${yellowcolor}Stopping bastion's docker...${normalcolor}\n"
    sleep 1
    docker container stop $remoteDockerName || error='y' 
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "${redcolor}failed. retrying in 5s...${normalcolor}\n"
        sleep 5
        error='n'
        docker container stop $remoteDockerName || error='y' 
        ((count=count+1))
    done
    printf "${greencolor}Stopped container...$remoteDockerName${normalcolor}\n"

    if [[ -n $clusterName ]]
    then
        printf "\n${yellowcolor}Removing cluster config file...${normalcolor}\n"
        ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'rm '$remoteDIR'/workload-clusters/tkg-'$clusterName'.yaml' && printf "REMOVED" || printf "FAILED"
        printf "\n"
    fi

    printf "\nNOTE:${bluecolor} You can choose to NOT remove the docker images in the remote jump/bastion host. (Recommended)"
    printf "\nThis will speed up the process to create workload cluster using this wizard next time."
    printf "\nHowever, removing the remote docker images it will free up spaces."
    printf "\nIf you have enough disk space in the bastion host it is recommended to NOT remove remote docker images.${normalcolor}"
    printf "\n"

    local confirmation='n'
    while true; do
        read -p "Would you like to remove $remoteDockerName images? [yn] " yn
        case $yn in
            [Yy]* ) confirmation='y'; printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) confirmation='n'; printf "\nyou confirmed no\n"; break;;
            * ) printf "${redcolor}Please answer y when you are ready.${normalcolor}\n";;
        esac
    done

    if [[ $confirmation == 'n' ]]
    then
        return 0
    fi

    printf "\nCleanup bastion's docker images..."
    sleep 2
    docker images rm $remoteDockerName || error='y'
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "\n${redcolor}failed to remove image $remoteDockerName. retrying in 3s...#$count${normalcolor}"
        sleep 3
        docker images rm $remoteDockerName || error='y'
        ((count=count+1))
    done
    
    printf "\nRemoving dangling images...."
    sleep 2
    docker rmi -f $(docker images -f "dangling=true" -q)
    
    printf "\nFreeing up space..."
    sleep 2
    docker volume prune -f

    printf "\nReseting docker context...."
    unset DOCKER_CONTEXT
    printf "COMPLETED\n"

    
    printf "\n${greencolor}==> DONE\n"
    printf "\n==> Cleanup process complete....${normalcolor}\n"

    return 0
}

function auto_tkgdeploy () {

    printf "\n\n*********Starting remote tanzu create on bastion host*************\n\n"

    local tkgconfigfile=$1

    prechecks $tkgconfigfile
    ret=$?
    if [[ $ret == 0 ]]
    then
        prepareRemote $tkgconfigfile
        ret=$?
        if [[ $ret == 0 ]]
        then
            startTKGCreate $tkgconfigfile
            ret=$?
            if [[ $ret == 0 ]]
            then
                downloadTKGFiles $tkgconfigfile
                ret=$?
                if [[ $ret == 0 ]]
                then
                    cleanBastion
                fi        
            fi            
        fi    
    fi   
}