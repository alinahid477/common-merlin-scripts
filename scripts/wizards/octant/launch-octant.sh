#!/bin/bash


if [[ -z $KUBE_CONFIG || $KUBE_CONFIG == "custom" ]]
then
    printf "\n\nCustom kubeconfig. Going to use kubeconfig as it is in $HOME/.kube dir...\n\n"
elif [[ -n $TKG_VSPHERE_CLUSTER_PASSWORD ]]
then
    export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)
    
    printf "\n\nNot a custom kubeconfig. Going to perform kubectl login\n\n"


    istokenexpired='n'
    # eg: cluster1:192.168.220.9,cluster2:192.168.220.7
    if [[ $TKG_VSPHERE_CLUSTERS == *[,]* ]]
    then
        printf "\nMultiple TKG_VSPHERE_CLUSTERS specified.....\n"
        printf "Checking token validity of the existing kubeconfig for all endpoints\n"
        
        vsphere_clusters=(`echo $TKG_VSPHERE_CLUSTERS | tr "," "\n"`)
        for vsphere_cluster in $vsphere_clusters
        do
            name_and_ip=(`echo $vsphere_cluster | tr ":" "\n"`)
            endpoint=${name_and_ip[1]}
        
            EXISTING_JWT_EXP=$(awk '/users/{flag=1} flag && /'$endpoint'/{flag2=1} flag2 && /token:/ {print $NF;exit}' /root/.kube/config | jq -R 'split(".") | .[1] | @base64d | fromjson | .exp')

            if [ -z "$EXISTING_JWT_EXP" ]
            then
                EXISTING_JWT_EXP=$(date  --date="yesterday" +%s)
            fi
            CURRENT_DATE=$(date +%s)


            if [ "$CURRENT_DATE" -gt "$EXISTING_JWT_EXP" ]
            then
                istokenexpired='y'
                printf "Token expired for endpoint: $endpoint. That's good enough. Skipping for the rest...\n"
                break
            fi        
        done
    else
        # eg: 192.168.220.9
        printf "\nSingle TKG_VSPHERE_CLUSTERS specified\n\n"
        printf "\nChecking token validity in the existing kubeconfig for $TKG_VSPHERE_CLUSTERS\n"
        name_and_ip=(`echo $vsphere_cluster | tr ":" "\n"`)
        endpoint=${name_and_ip[1]}
        EXISTING_JWT_EXP=$(awk '/users/{flag=1} flag && /'$endpoint'/{flag2=1} flag2 && /token:/ {print $NF;exit}' /root/.kube/config | jq -R 'split(".") | .[1] | @base64d | fromjson | .exp')

        if [ -z "$EXISTING_JWT_EXP" ]
        then
            EXISTING_JWT_EXP=$(date  --date="yesterday" +%s)
        fi
        CURRENT_DATE=$(date +%s)


        if [ "$CURRENT_DATE" -gt "$EXISTING_JWT_EXP" ]
        then
            istokenexpired='y'
            printf "Token expired for endpoint: $endpoint....\n"
            break
        fi
    fi

    if [[ istokenexpired == 'y' ]]
    then
        rm /root/.kube/config
        rm -R /root/.kube/cache
    fi

    printf "\n\n\n**********vSphere Cluster login...*************\n"

    
    if [[ $TKG_VSPHERE_CLUSTERS == *[,]* ]]
    then
        printf "\n\n\n***********Muliple clusters specified via TKG_VSPHERE_CLUSTERS=$TKG_VSPHERE_CLUSTERS...*************\n"


        vsphere_clusters=(`echo $TKG_VSPHERE_CLUSTERS | tr "," "\n"`)
        for vsphere_cluster in $vsphere_clusters
        do
            name_and_ip=(`echo $vsphere_cluster | tr ":" "\n"`)
            vsphere_cluster_name=${name_and_ip[0]}
            vsphere_cluster_ip=${name_and_ip[1]}
            
            printf "\n\n\n***********Login $vsphere_cluster_name=$vsphere_cluster_ip...*************\n"
            kubectl vsphere login --tanzu-kubernetes-cluster-name $vsphere_cluster_name --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME
            
            printf "\n\n\n***********Adjust kubeconfig $vsphere_cluster_name=$vsphere_cluster_ip...*************\n"
            sed -i 's/kubernetes/'$TKG_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
            sed -i '0,/'$vsphere_cluster_ip'/s//kubernetes/' ~/.kube/config
            mv ~/.kube/config ~/.kube/config-$vsphere_cluster_name
            
            sleep 2
        done
    else
        printf "\n\n\n***********Single cluster specified via TKG_VSPHERE_CLUSTERS=$TKG_VSPHERE_CLUSTERS...*************\n"

        name_and_ip=(`echo $TKG_VSPHERE_CLUSTERS | tr ":" "\n"`)
        vsphere_cluster_name=${name_and_ip[0]}
        vsphere_cluster_ip=${name_and_ip[1]}

        printf "\n\n\n***********Authenticating to cluster $vsphere_cluster_name-->IP:$vsphere_cluster_ip  ...*************\n"
        printf "\n\n\n***********Login $vsphere_cluster_name...*************\n"
        kubectl vsphere login --tanzu-kubernetes-cluster-name $vsphere_cluster_name --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME
        
        printf "\n\n\n***********Adjusting your kubeconfig...*************\n"

        sed -i 's/kubernetes/'$TKG_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
        kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME

        sed -i '0,/'$vsphere_cluster_ip'/s//kubernetes/' ~/.kube/config
        if [[ -z $BASTION_TUNNELS ]] 
        then
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$vsphere_cluster_ip:6443 $BASTION_USERNAME@$BASTION_HOST
        fi
    fi

fi




    

# printf "\n\n\n***********Verifying...*************\n"
# kubectl get ns

# printf "\nDid it list the namespaces in the k8s? If not something went wrong. Please verify the env variables and check connectivity."

printf "\n\n\nGoing to launch octact.\n"

# /bin/bash
octant