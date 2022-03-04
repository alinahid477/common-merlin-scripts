#!/bin/bash
export $(cat /root/.env | xargs)

remoteDIR="~/merlin/merlin-tkg"
remoteDockerName="merlin-tkg-remote"
localBastionDIR=$HOME/binaries/bastion
localDockerContextName="merlin-bastion-docker-tkg"

function prechecks () {
    printf "\n\n\n*********performing prerequisites checks************\n\n\n"

    printf "checking presence of $HOME/.ssh/id_rsa...."
    isexist=$(ls $HOME/.ssh/id_rsa)
    if [[ -z $isexist ]]
    then
        printf "\nERROR: Failed. id_rsa file must exist in .ssh directory..."
        printf "\nPlease ensure to place id_rsa file in .ssh directory and the id_rsa.pub in .ssh of $BASTION_USERNAME@$BASTION_HOST"
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

    printf "\nChecking Docker on $BASTION_USERNAME@$BASTION_HOST..."
    isexist=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'docker --version')
    if [[ -z $isexist ]]
    then
        printf "\nERROR: Failed. Docker not installed on bastion host..."
        printf "\nPlease install docker on host $BASTION_HOST to continue..."
        returnOrexit || return 1
    else
        printf "FOUND.\nDetails: $isexist\n\n"
    fi
    printf "\nChecking python3 on $BASTION_USERNAME@$BASTION_HOST...."
    isexist=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'python3 --version')
    if [[ -z $isexist ]]
    then
        printf "python3 not found.\nchecking python on $BASTION_USERNAME@$BASTION_HOST...."
        isexist=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'python3 --version')
        if [[ -z $isexist ]]
        then
            printf "\nERROR: Failed. Python not installed on bastion host..."
            printf "\nPlease install Python on host $BASTION_HOST to continue..."
            returnOrexit || return 1
        else
            printf "FOUND.\nDetails: $isexist\n\n"
        fi
    else
        printf "FOUND\nDetails: $isexist\n\n"
    fi

    return 0
}


function prepareRemote () {
    printf "\n\n\n********Preparing $BASTION_USERNAME@$BASTION_HOST for merlin*********\n\n\n"

    isexist=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls -l '$remoteDIR)
    if [[ -z $isexist ]]
    then
        printf "\nCreating directory 'merlin' in $BASTION_USERNAME@$BASTION_HOST home dir"
        ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'mkdir -p '$remoteDIR'/binaries' || returnOrexit || return 1
        ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'mkdir -p '$remoteDIR'/.ssh' || returnOrexit || return 1
    fi
    


    printf "\nGetting remote files list from $BASTION_USERNAME@$BASTION_HOST\n"
    ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls '$remoteDIR'/binaries/' > /tmp/bastionhostbinaries.txt || returnOrexit || return 1
    ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls '$remoteDIR'/' > /tmp/bastionhosthomefiles.txt || returnOrexit || return 1
    ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls '$remoteDIR'/.ssh/' >> /tmp/bastionhosthomefiles.txt || returnOrexit || return 1





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

    if [[ -n $MANAGEMENT_CLUSTER_CONFIG_FILE ]]
    then
        printf "\nUploading $MANAGEMENT_CLUSTER_CONFIG_FILE\n"
        scp $MANAGEMENT_CLUSTER_CONFIG_FILE $BASTION_USERNAME@$BASTION_HOST:$remoteDIR/ || returnOrexit || return 1
    fi

    return 0
}


function startTKGCreate () {
    printf "\n\n\n**********Starting remote docker with tanzu cli...*********\n\n\n"
    ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'chmod +x '$remoteDIR'/bastionhostrun.sh && '$remoteDIR'/bastionhostrun.sh '$DOCKERHUB_USERNAME $DOCKERHUB_PASSWORD $remoteDockerName


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
        count=1
        while [[ -z $isexist && $count -lt 4 ]]; do
            printf "\nContainer not running... Retrying in 5s"
            sleep 5
            isexist=$(docker ps --filter "name=$remoteDockerName" --format "{{.Names}}")
            ((count=count+1))
        done
    fi
    if [[ -z $isexist ]]
    then
        printf "\nERROR: Remote container $remoteDockerName not running."
        printf "\nUnable to proceed further. Please check merling directory in your bastion host.\n"
        returnOrexit || return 1
    fi


    printf "\nPerforming ssh-add..."
    docker exec -idt $remoteDockerName bash -c "cd ~ ; ssh-add ~/.ssh/id_rsa" || returnOrexit || return 1
    printf "COMPLETED\n"

    printf "\nStarting tanzu in remote context..."
    if [[ -n $MANAGEMENT_CLUSTER_CONFIG_FILE ]]
    then
        # homepath=$(ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'pwd')
        filename=$(echo $MANAGEMENT_CLUSTER_CONFIG_FILE| rev | awk -v FS='/' '{print $1}' | rev)
        printf "\nLaunching management cluster create using $MANAGEMENT_CLUSTER_CONFIG_FILE..."
        docker exec -idt $remoteDockerName bash -c "cd ~ ; tanzu management-cluster create --file $remoteDIR/$filename -v 9" || returnOrexit || return 1
    else
        printf "\nLaunching management cluster create using UI..."
        printf "\nDEBUG docker exec -idt $remoteDockerName bash -c \"cd ~ ; tanzu management-cluster create --ui -y -v 9 --browser none\" || returnOrexit || return 1"
        docker exec -idt $remoteDockerName bash -c "cd ~ ; tanzu management-cluster create --ui -y -v 9 --browser none" || returnOrexit || return 1
    fi
    printf "COMPLETED\n"

    
    if [[ ! -f  $HOME/.ssh/ssh_config ]]
    then
        printf "\nSetting up for sshuttle with bastion host..."
        chmod 0600 $HOME/.ssh/*
        cp $HOME/.ssh/sshuttleconfig $HOME/.ssh/ssh_config || returnOrexit || return 1 
        # mv /etc/ssh/ssh_config /etc/ssh/ssh_config-default
        # ln -s $HOME/.ssh/ssh_config /etc/ssh/ssh_config
        printf "COMPLETED\n"
    fi
    
    export SSHUTTLE=true
    printf "\n\n\n"
    printf "=> Establishing sshuttle with remote $BASTION_USERNAME@$BASTION_HOST...."
    sshuttle --dns --python python2 -D -r $BASTION_USERNAME@$BASTION_HOST 0/0 -x $BASTION_HOST/32 --disable-ipv6 --listen 0.0.0.0:0 || returnOrexit || return 1
    printf "COMPLETED.\n"


    printf "\n\n\n Here's your public key in $HOME/.ssh/id_rsa.pub:\n"
    cat $HOME/.ssh/tkg_rsa.pub
    printf "\n\n\nAccess installation UI at http://127.0.0.1:8080"


    containercreated='n'
    containerdeleted='n'
    dobreak='n'
    count=1
    while [[ $dobreak == 'n' && $count -lt 30 ]]; do
        sleep 3m
        printf "\nChecking progres...#$count\n"
        ((count=count+1))
        if [[ $containercreated == 'n' ]]
        then
            printf "Checking bootstrap cluster created..."
            isexist=$(docker container ls | grep "projects.registry.vmware.com/tkg/kind/node" || printf "")
            if [[ -n $isexist ]]
            then
                containercreated='y'
                count=1
                printf "YES"
            else
                printf "NO"
            fi
            printf "\n"
        else
            if [[ $containerdeleted == 'n' ]]
            then
                printf "Checking bootstrap cluster uploaded..."
                dockers=$(docker ps --format "{{.Image}}" || printf "error")
                if [[ -n $dockers && $dockers != "error" ]]
                then
                    isexist=$(printf "$dockers" | grep "projects.registry.vmware.com/tkg/kind/node")
                else
                    isexist='no'
                fi
                if [[ -z $isexist ]]
                then
                    containerdeleted='y'
                    count=1
                    printf "YES"
                else
                    printf "NO"
                fi
                printf "\n"
            fi
        fi
        if [[ $containercreated == 'y' && $containerdeleted == 'y' ]]
        then
            sleep 3
            printf "\nTKG management cluster should have been deployed...\n"
            
            local confirmation='y'
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                while true; do
                    read -p "Confirm to continue [yn]? " yn
                    case $yn in
                        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                        [Nn]* ) confirmation='n'; printf "\nyou confirmed no\n"; break;;
                        * ) echo "Please answer y when you are ready.";;
                    esac
                done
            else
                printf "\nGoing to wait for 1m\n"
                sleep 1m
            fi

            if [[ $confirmation == 'y' ]]
            then
                count=100
                dobreak='y'
            fi
            
        fi
    done



    printf "\n==> TGK management cluster deployed -->> DONE.\n"
    printf "\nWaiting 30s before shuttle shutdown...\n"
    sleep 30

    printf "\nStopping sshuttle..."
    sshuttlepid=$(ps aux | grep "/usr/bin/sshuttle --dns" | awk 'FNR == 1 {print $2}')
    if [[ -n $sshuttlepid ]]
    then
        kill $sshuttlepid && unset SSHUTTLE
        if [[ -z $SSHUTTLE ]]
        then
            printf "COMPLETED\n"
        else
            printf "FAILED\n"
        fi
    fi
    sleep 2



    local confirmation='y'
    if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
    then
        while true; do
            read -p "Confirm to continue [yn]? " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) confirmation='n'; printf "\nyou confirmed no\n"; break;;
                * ) echo "Please answer y when you are ready.";;
            esac
        done
    else
        printf "\nGoing to wait for 2s\n"
        sleep 2
    fi

    if [[ $confirmation == 'n' ]]
    then
        returnOrexit || return 1
    fi

    return 0
}









function downloadTKGFiles () {
    printf "\n\n\n***********Downloading files from bastion host...***********\n\n\n"

    printf "\nDownloading management cluster configs from ~/.config/tanzu/tkg/clusterconfigs/...\n"
    cd ~
    mkdir -p $HOME/.config/tanzu/tkg/clusterconfigs
    filename=$(docker exec $remoteDockerName ls -1tc ~/.config/tanzu/tkg/clusterconfigs/ | head -1 || printf "")
    count=1
    while [[ -z $filename && $count -lt 5 ]]; do
        printf "failed getting filename. retrying in 5s...\n"
        sleep 5
        filename=$(docker exec $remoteDockerName ls -1tc ~/.config/tanzu/tkg/clusterconfigs/ | head -1 || printf "")
        ((count=count+1))
    done
    sleep 1
    error='n'
    docker exec $remoteDockerName cat ~/.config/tanzu/tkg/clusterconfigs/$filename > $HOME/.config/tanzu/tkg/clusterconfigs/$filename || error='y'
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "failed downloading. retrying in 5s...\n"
        sleep 5
        error='n'
        docker exec $remoteDockerName cat ~/.config/tanzu/tkg/clusterconfigs/$filename > $HOME/.config/tanzu/tkg/clusterconfigs/$filename || error='y'
        ((count=count+1))
    done


    sleep 1
    printf "\nDownloading ~/.config/tanzu/config.yaml...\n"
    error='n'
    docker exec $remoteDockerName cat ~/.config/tanzu/config.yaml > $HOME/.config/tanzu/config.yaml || error='y'
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "failed downloading. retrying in 5s...\n"
        sleep 5
        error='n'
        docker exec $remoteDockerName cat ~/.config/tanzu/config.yaml > $HOME/.config/tanzu/config.yaml || error='y'
        ((count=count+1))
    done

    sleep 1
    printf "\nDownloading ~/.config/tanzu/tkg/cluster-config.yaml...\n"
    error='n'
    docker exec $remoteDockerName cat ~/.config/tanzu/tkg/cluster-config.yaml > $HOME/.config/tanzu/tkg/cluster-config.yaml || error='y'
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "failed downloading. retrying in 5s...\n"
        sleep 5
        error='n'
        docker exec $remoteDockerName cat ~/.config/tanzu/tkg/cluster-config.yaml > $HOME/.config/tanzu/tkg/cluster-config.yaml || error='y'
        ((count=count+1))
    done

    sleep 1
    printf "\nDownloading ~/.config/tanzu/tkg/features.json...\n"
    error='n'
    docker exec $remoteDockerName cat ~/.config/tanzu/tkg/features.json > $HOME/.config/tanzu/tkg/features.json || error='y'
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "failed downloading. retrying in 5s...\n"
        sleep 5
        error='n'
        docker exec $remoteDockerName cat ~/.config/tanzu/tkg/features.json > $HOME/.config/tanzu/tkg/features.json || error='y'
        ((count=count+1))
    done

    sleep 1
    printf "\nDownloading ~/.kube/config...\n"
    error='n'
    docker exec $remoteDockerName cat ~/.kube/config > $HOME/.kube/config || error='y'
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "failed downloading kubeconfig. retrying in 5s...\n"
        sleep 5
        error='n'
        docker exec $remoteDockerName cat ~/.kube/config > $HOME/.kube/config || error='y'
        ((count=count+1))
    done

    mkdir -p ~/.kube-tkg
    sleep 1
    printf "\nDownloading ~/.kube-tkg/config...\n"
    error='n'
    docker exec $remoteDockerName cat ~/.kube-tkg/config > $HOME/.kube-tkg/config || error='y'
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "failed downloading ~/.kube-tkg/kubeconfig. retrying in 5s...\n"
        sleep 5
        error='n'
        docker exec $remoteDockerName cat ~/.kube-tkg/config > $HOME/.kube-tkg/config || error='y'
        ((count=count+1))
    done

    # scp -r $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/.config/tanzu/tkg/clusterconfigs ~/.config/tanzu/tkg/
    sleep 2
    printf "==> DONE\n"
    # sleep 10
    # tanzu cluster list
    # tanzu cluster kubeconfig get  --admin
    return 0
}




function cleanBastion () {
    printf "\n\n\n***********crealing bastion host...***********\n\n\n"
    local confirmation='n'
    while true; do
        read -p "Confirm to continue? [yn] " yn
        case $yn in
            [Yy]* ) confirmation='y'; printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) confirmation='n'; printf "\nyou confirmed no\n"; break;;
            * ) echo "Please answer y when you are ready.";;
        esac
    done

    if [[ $confirmation == 'n' ]]
    then
        returnOrexit || return 1
    fi

    printf "\nCleanup bastion's docker..."
    sleep 2
    containerid=$(docker ps -aqf "name=^$remoteDockerName$" || printf "")
    count=1
    while [[ -z $containerid && $count -lt 5 ]]; do
        printf "\nfailed to find container id. retrying in 5s...#$count"
        sleep 5
        containerid=$(docker ps -aqf "name=^$remoteDockerName$" || printf "")
        ((count=count+1))
    done
    printf "\nDocker container found $remoteDockerName=$containerid. Stopping container..."
    error='n'
    docker container stop $containerid || error='y' 
    count=1
    while [[ $error == 'y' && $count -lt 5 ]]; do
        printf "\nfailed to stop container $containerid. retrying in 5s...#$count"
        sleep 5
        error='n'
        docker container stop $containerid || error='y' 
        ((count=count+1))
    done
    printf "\nDocker container $remoteDockerName stoppped."

    printf "\nRemoving container $containerid...."
    docker container rm $containerid
    sleep 2
    docker container rm $(docker container ls --all -q)
    
    printf "\nFreeing up space..."
    sleep 2
    docker volume prune -f
    
    printf "\nRemoving dangling images...."
    sleep 2
    docker rmi -f $(docker images -f "dangling=true" -q)
    sleep 2
    docker rmi -f $(docker images -q)
    printf "\nRemoved docker images...\n"

    printf "\nReseting docker context...."
    unset DOCKER_CONTEXT
    printf "COMPLETED\n"

    # printf "\n\n"
    # printf "\nDuring the installation process Tanzu CLI created few files in the bastion host under directory ~/merlin of user $BASTION_USERNAME"
    # printf "\nNecessary files are downloaded on your local (this docker container) directory for local connection to tanzu kubernetes grid."
    # printf "\nThus you have copy of the required files in your local so it is safe to delete the remote files."
    # printf "\nHowever, If you have enough space on the bastion host you may choose keep these files on the bastion host, just in case."
    # printf "\nYou may also choose to delete these files."
    # printf "\n\n"
    # isremoveremotefiles='n'
    # while true; do
    #     read -p "Would you like to remove Tanzu CLI files from bastion host? [yn]: " yn
    #     case $yn in
    #         [Yy]* ) isremoveremotefiles='y'; printf "\nyou confirmed yes\n"; break;;
    #         [Nn]* ) printf "\nyou said no.\n"; break;;
    #         * ) echo "Please answer y or n to proceed...";;
    #     esac
    # done
    # if [[ $isremoveremotefiles == 'y' ]]
    # then
    #     printf "\nCleanup bastion's files...\n"
    #     sleep 2
    #     error='n'
    #     docker exec merlintkgonvsphere rm -r ~/.cache/ ~/.config/ ~/.local/ ~/.kube-tkg/ ~/.kube/ || error='y'
    #     count=1
    #     while [[ $error == 'y' && $count -lt 5 ]]; do
    #         printf "failed. retrying in 5s...\n"
    #         sleep 5
    #         error='n'
    #         docker exec merlintkgonvsphere rm -r ~/.cache/ ~/.config/ ~/.local/ ~/.kube-tkg/ ~/.kube/ || error='y'
    #         ((count=count+1))
    #     done
    #     printf "\nRemoved configs and caches files..."
    #     sleep 2
    #     ssh -i $HOME/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'rm -r ~/merlin/tkgonvsphere'
    #     printf "\nRemoved tkgonvsphere under ~/merlin/..."
    # fi



    printf "\n==> DONE\n"
    printf "\n==> Cleanup process complete....\n"

    return 0
}





function auto_tkginstall () {
    prechecks
    ret=$?
    if [[ $ret == 0 ]]
    then
        prepareRemote
        ret=$?
        if [[ $ret == 0 ]]
        then
            startTKGCreate
            ret=$?
            if [[ $ret == 0 ]]
            then
                downloadTKGFiles
                ret=$?
                if [[ $ret == 0 ]]
                then
                    cleanBastion
                fi        
            fi            
        fi    
    fi   
}


# printf "\nStarting sshuttle...\n"
# sshuttle --dns --python python2 -D -r $BASTION_USERNAME@$BASTION_HOST 0/0 -x $BASTION_HOST/32 --disable-ipv6 --listen 0.0.0.0:0