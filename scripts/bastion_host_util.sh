#!/bin/bash

test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true


function checkBastionHost () {

    if [[ -z $BASTION_HOST ]]
    then
        printf "\nERROR: Bastion host is not set in the environment variable.\n"
        returnOrexit || return 1
    fi

    isexists=$(ls $HOME/.ssh/id_rsa)
    if [[ -z $isexists ]]
    then
        printf "\nERROR: Bastion host parameter supplied BUT no id_rsa file present in .ssh\n"
        printf "\nPlease place a id_rsa file in $HOME/.ssh dir"
        printf "\nQuiting...\n\n"
        returnOrexit || return 1
    fi
}

# Parameters (required): [Host:Port] OR [http(s) Url] or http url:port. 
# eg: 192.168.220.2:6443 OR https://myendpoint.aws.bla.vla.com or http://myendpoint.aws.bla.vla.com or http://myendpoint.aws.bla.vla.com:6443
function create_bastion_tunnel () {
    checkBastionHost

    if [[ -z $1 ]]
    then
        printf "\nERROR: No host or url param passed.\n"
        returnOrexit || return 1
    fi

    local increasePortCount=0
    if [[ -n $2 ]] 
    then
        increasePortCount=$2
    fi

    unset url
    unset host
    unset port

    proto="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"

    if [[ -z $proto ]]
    then
        # Meaning this is ip address
        host=$1
    else
        # Meaning this is url. extract host, port from url
        # remove the protocol
        url="$(echo ${1/$proto/})"
        host="$(echo ${url} | cut -d/ -f1)"
    fi

    port="$(echo $host | awk -F: '{print $2}')"
    host="$(echo $host | awk -F: '{print $1}')"
    
    if [[ $host == 'kubernetes' ]]
    then
        printf "\nWARNING: found $host as the host name. Will not create tunnel with this name.\n"
        returnOrexit || return 1
    fi

    if [[ -z $port ]]
    then
        if [[ -z $proto || $proto == 'http://' ]]
        then
            port=80
        else 
            port=443
        fi                    
        printf "\nWARNING: no port specified. Determined port to be: $port\n"
    fi

    local hostPort=$port
    ((hostPort=$hostPort+$increasePortCount))

    printf "\nChecking existing bastion tunnel for $port on tcp..."
    local pid=$(netstat -ntlp | egrep "*tcp.*:6443.*LISTEN" | awk '{print $7}' | awk -F/ '{print $1}')
    if [[ -n $pid ]]
    then
        printf "FOUND. PID:$pid"
        printf "\nKILL process $pid..."
        kill -9 $pid && printf "KILLED\n" || printf "Failed.\n"
    else
        printf "NOT FOUND\n"
    fi
    printf "\nCreating bastion tunnel for $hostPort:$host:$port through bastion $BASTION_USERNAME@$BASTION_HOST..."
    sleep 1
    ssh -i $HOME/.ssh/id_rsa -4 -fNT -L $hostPort:$host:$port $BASTION_USERNAME@$BASTION_HOST || returnOrexit || return 1
    printf "Tunnel CREATED.\n"
}


function create_bastion_tunnel_for_cluster_endpoints () {
    local CLUSTER_ENDPOINTS=$1
    if [[ -z $CLUSTER_ENDPOINTS ]]
    then
        printf "\nERROR: endpoints missing.\n"
        returnOrexit || return 1
    fi

    if [[ $CLUSTER_ENDPOINTS == *[,]* ]]
    then
        printf "Multiple endpoints specified\n"
        CLUSTER_ENDPOINTS_ARR=$(echo $CLUSTER_ENDPOINTS | tr "," "\n")
        local entryCount=0
        for clusterEndpoint in $CLUSTER_ENDPOINTS_ARR
        do
            proto="$(echo $clusterEndpoint | grep :// | sed -e's,^\(.*://\).*,\1,g')"
            serverurl="$(echo ${clusterEndpoint/$proto/} | cut -d/ -f1)"
            port="$(echo $serverurl | awk -F: '{print $2}')"
            serverurl="$(echo $serverurl | awk -F: '{print $1}')"
            
            printf "Creating tunnel for $proto$serverurl:$port..."
            create_bastion_tunnel "$proto$serverurl:$port" $entryCount && printf "Tunnel Created\n" || printf "Failed.\n"

            ((entryCount=$entryCount+1))
        done
    else
        printf "Single management cluster endpoint specified\n"
        
        proto="$(echo $CLUSTER_ENDPOINTS | grep :// | sed -e's,^\(.*://\).*,\1,g')"
        serverurl="$(echo ${CLUSTER_ENDPOINTS/$proto/} | cut -d/ -f1)"
        port="$(echo $serverurl | awk -F: '{print $2}')"
        serverurl="$(echo $serverurl | awk -F: '{print $1}')"
        
        printf "Creating tunnel for $proto$serverurl:$port..."
        create_bastion_tunnel "$proto$serverurl:$port" && printf "Tunnel Created\n" || printf "Failed.\n"
    fi

    
}

# params (required): path/to/kubeconfig
# eg: $HOME/.kube-tkg/config
function create_bastion_tunnel_from_kubeconfig () {
    
    local kubeconfigfile=''
    
    # $1=endpoint url or kubeconfig file
    if [[ -n $1 ]]
    then
        isurl=$(echo $1 | grep -io 'http[s]*://[^"]*')
        if [[ -n $isurl ]]
        then
            printf "\nERROR: Supplied param is url. This is not allowed. Use method: \"create_bastion_tunnel\" instead.\n"
            returnOrexit || return 1
        fi    
        kubeconfigfile=$1
    else
        printf "\nERROR: required param kubeconfig file path not supplied.\n"
        returnOrexit || return 1
    fi

    # this will hold the name of the environment variable to write on .env file if needed.
    # in the case of tkgm/tce it will have a environment variable or to be writted.
    # but there may also be cases where it is simply about creating tunnel and env variable doesnt need to be create
    # eg: $2 is MANAGEMENT_CLUSTER_ENDPOINTS for tkgm or tce and for workload TKC TKG_CLUSTER_ENDPOINTS
    local clusterEndpointsVariableName=$2
    local clusterEndpoints=''
    if [[ -n $clusterEndpointsVariableName ]]
    then
        clusterEndpoints=${!clusterEndpointsVariableName}
    fi

    

    printf "\nExtracting server info from kubeconfig..."
    # serverurl=$(awk '/server/ {print $NF;exit}' $kubeconfigfile | awk -F/ '{print $3}' | awk -F: '{print $1}')
    # port=$(awk '/server/ {print $NF;exit}' $kubeconfigfile | awk -F/ '{print $3}' | awk -F: '{print $2}')
    readarray -t serveraddresses < <(parse_yaml $kubeconfigfile | awk -F= '{if ($1=="clusters__server" || $1=="clusters_name_server") print $2 }' | xargs) 
    local count=0
    local status=''
    for serveraddress in ${serveraddresses[@]}; do
        serverurl=$(echo $serveraddress | awk -F/ '{print $3}' | awk -F: '{print $1}')
        port=$(echo $serveraddress | awk -F/ '{print $3}' | awk -F: '{print $2}')
        if [[ $serverurl != 'kubernetes' ]]
        then
            if [[ -z $clusterEndpoints ]]
            then
                clusterEndpoints=$(echo "$serverurl:$port")
            else
                clusterEndpoints=$(echo "$clusterEndpoints,$serverurl:$port")
            fi
            printf "Tunnel for host: $serverurl, port: $port..."
            status=''
            create_bastion_tunnel "$serverurl:$port" $count && status="CREATED" || status="FAILED"
            

            if [[ -n $status && -n $status='CREATED' ]]
            then
                printf "\nAdjusting kubeconfig for tunneling..."
                sed -i '0,/'$serverurl'/s//kubernetes/' $kubeconfigfile
                local x=$(echo $kubeconfigfile | xargs) 
                if [[ -f $HOME/.kube/config && "$kubeconfigfile" != "$HOME/.kube/config" ]]
                then
                    sed -i '0,/'$serverurl'/s//kubernetes/' $HOME/.kube/config
                fi
            fi
            printf "$status\n"

            ((count=$count+1))
        fi        
    done
       

    if [[ -n $clusterEndpoints && -n $clusterEndpointsVariableName ]]
    then
        # only wtite in env file if the env variable name is supplied.
        # otherwise assume only tunnel create.
        printf "Writting environment variable $clusterEndpointsVariableName in .env file..."
        sed -i '/'$clusterEndpointsVariableName'/d' $HOME/.env
        printf "\n$clusterEndpointsVariableName=$clusterEndpoints" >> $HOME/.env
        printf "DONE.\n"
    fi
}


function modifyConfigFileForTunnel () {
    local sourceFile=$1
    local destinationFile=$2
    local CLUSTER_ENDPOINTS=$3

    if [[ -z $sourceFile || -z $destinationFile ]]
    then
        printf "\n${redcolor}ERROR: Source or destination filename not supplied.${normalcolor}\n"
        returnOrexit || return 1
    fi
    
    if [[ -z $CLUSTER_ENDPOINTS ]]
    then
        printf "\n${redcolor}ERROR: endpoints missing.${normalcolor}\n"
        returnOrexit || return 1
    fi

    cp $sourceFile $destinationFile

    if [[ $CLUSTER_ENDPOINTS == *[,]* ]]
    then
        printf "Multiple endpoints specified\n"
        CLUSTER_ENDPOINTS_ARR=$(echo $CLUSTER_ENDPOINTS | tr "," "\n")
        for clusterEndpoint in $CLUSTER_ENDPOINTS_ARR
        do
            # This is flawd logic. I couldn't think of a way now. Need to look into it later.
            # For now this should not happen as management cluster is going to be sigle per container.

            proto="$(echo $clusterEndpoint | grep :// | sed -e's,^\(.*://\).*,\1,g')"
            serverurl="$(echo ${clusterEndpoint/$proto/} | cut -d/ -f1)"
            port="$(echo $serverurl | awk -F: '{print $2}')"
            serverurl="$(echo $serverurl | awk -F: '{print $1}')"
            
            printf "Modifying file for $proto$serverurl:$port..."
            sed -i '0,/kubernetes/s//'$serverurl'/' $destinationFile && printf "OK\n" || printf "Failed.\n"
        done
    else
        printf "Single management cluster endpoint specified\n"
        
        proto="$(echo $CLUSTER_ENDPOINTS | grep :// | sed -e's,^\(.*://\).*,\1,g')"
        serverurl="$(echo ${CLUSTER_ENDPOINTS/$proto/} | cut -d/ -f1)"
        port="$(echo $serverurl | awk -F: '{print $2}')"
        serverurl="$(echo $serverurl | awk -F: '{print $1}')"
        
        printf "Modifying file for $proto$serverurl:$port..."
        sed -i '0,/kubernetes/s//'$serverurl'/' $destinationFile && printf "OK\n" || printf "Failed.\n"
    fi    
}


function create_bastion_tunnel_auto_tkg () {
    if [[ -n $MANAGEMENT_CLUSTER_ENDPOINTS ]]
    then
        create_bastion_tunnel_for_cluster_endpoints $MANAGEMENT_CLUSTER_ENDPOINTS || returnOrexit || return 1
    else
        # $1 containing kubeconfig path
        if [[ -z $1 ]]
        then
            create_bastion_tunnel_from_kubeconfig "$HOME/.kube-tkg/config" "MANAGEMENT_CLUSTER_ENDPOINTS" || returnOrexit || return 1
        else
            create_bastion_tunnel_from_kubeconfig $1 "MANAGEMENT_CLUSTER_ENDPOINTS" || returnOrexit || return 1
        fi
    fi
}

