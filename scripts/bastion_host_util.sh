#!/bin/bash

export $(cat /root/.env | xargs)


returned='n'
function returnOrexit()
{
    returned='n'
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        returned='y'
        return 1
    else
        exit
    fi
}


function checkBastionHost () {

    if [[ -z $BASTION_HOST ]]
    then
        printf "\nERROR: Bastion host is not set in the environment variable.\n"
        returnOrexit && return 1
    fi

    isexists=$(ls ~/.ssh/id_rsa)
    if [[ -z $isexists ]]
    then
        printf "\nERROR: Bastion host parameter supplied BUT no id_rsa file present in .ssh\n"
        printf "\nPlease place a id_rsa file in ~/.ssh dir"
        printf "\nQuiting...\n\n"
        returnOrexit && return 1
    fi
}

# Parameters (required): [Host:Port] OR [http(s) Url] or http url:port. 
# eg: 192.168.220.2:6443 OR https://myendpoint.aws.bla.vla.com or http://myendpoint.aws.bla.vla.com or http://myendpoint.aws.bla.vla.com:6443
function create_bastion_tunnel () {
    checkBastionHost

    if [[ -z $1 ]]
    then
        printf "\nERROR: No host or url param passed.\n"
        returnOrexit && return 1
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
        returnOrexit && return 1
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

    printf "\nCreating bastion tunnel for $host:$port through bastion $BASTION_USERNAME@$BASTION_HOST..."
    sleep 1
    ssh -i /root/.ssh/id_rsa -4 -fNT -L $port:$host:$port $BASTION_USERNAME@$BASTION_HOST || returnOrexit || return 1
    printf "Tunnel CREATED.\n"
}


function create_bastion_tunnel_from_management_cluster_endpoint () {
    if [[ -z $MANAGEMENT_CLUSTER_ENDPOINT ]]
    then
        printf "\nERROR: MANAGEMENT_CLUSTER_ENDPOINT missing from environment variable.\n"
        returnOrexit && return 1
    fi

    proto="$(echo $MANAGEMENT_CLUSTER_ENDPOINT | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    serverurl="$(echo ${MANAGEMENT_CLUSTER_ENDPOINT/$proto/} | cut -d/ -f1)"
    port="$(echo $serverurl | awk -F: '{print $2}')"
    serverurl="$(echo $serverurl | awk -F: '{print $1}')"
    

    create_bastion_tunnel "$proto$serverurl:$port" || returnOrexit || return 1
}

# params (required): path/to/kubeconfig
# eg: ~/.kube-tkg/config
function create_bastion_tunnel_from_kubeconfig () {
    # $1=endpoint url or kubeconfig file
    if [[ -n $1 ]]
    then
        isurl=$(echo $1 | grep -io 'http[s]*://[^"]*')
        if [[ -n $isurl ]]
        then
            printf "\nERROR: Supplied param is url. This is not allowed. Use method: \"create_bastion_tunnel\" instead.\n"
            returnOrexit && return 1
        fi    
        kubeconfigfile=$1
    else
        printf "\nERROR: required param kubeconfig file path not supplied.\n"
        returnOrexit && return 1
    fi

    printf "\nExtracting server info from kubeconfig..."
    serverurl=$(awk '/server/ {print $NF;exit}' $kubeconfigfile | awk -F/ '{print $3}' | awk -F: '{print $1}')
    port=$(awk '/server/ {print $NF;exit}' $kubeconfigfile | awk -F/ '{print $3}' | awk -F: '{print $2}')
    printf "host: $serverurl, port: $port"

    create_bastion_tunnel "$serverurl:$port" || returnOrexit || return 1

    if [[ -z $MANAGEMENT_CLUSTER_ENDPOINT && $returned == 'n' && $serverurl != 'kubernetes' ]]
    then
        printf "\nAdjusting kubeconfig for tunneling..."
        sed -i '0,/'$serverurl'/s//kubernetes/' $kubeconfigfile
        isexist=$(ls ~/.kube/config)
        if [[ -n $isexist ]]
        then
            sed -i '0,/'$serverurl'/s//kubernetes/' ~/.kube/config
        fi
        sleep 1
        printf "\nMANAGEMENT_CLUSTER_ENDPOINT=$serverurl:$port" >> $HOME/.env
        printf "DONE.\n"
    fi

}


function create_bastion_tunnel_auto_tkg () {
    if [[ -n $MANAGEMENT_CLUSTER_ENDPOINT ]]
    then
        create_bastion_tunnel_from_management_cluster_endpoint
    else
        # $1 containing kubeconfig path
        if [[ -z $1 ]]
        then
            create_bastion_tunnel_from_kubeconfig "$HOME/.kube-tkg/config"
        else
            create_bastion_tunnel_from_kubeconfig $1
        fi
    fi
}

