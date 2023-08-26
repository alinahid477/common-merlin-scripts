#!/bin/bash

extractTAPIngress () {
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

    printf "\nExtracting ip for accessing the tap....\n"
    echo "" >> $HOME/configs/output
    local lbip='';
    local nodeport='';
    if [[ -n $USE_LOAD_BALANCER && $USE_LOAD_BALANCER == false ]]
    then
        lbip=$(kubectl get svc -n tanzu-system-ingress -o json | jq -r '.items[] | select(.spec.type == "NodePort" and .metadata.name == "envoy") | .spec.clusterIP')
        if [[ -z $lbip || $lbip == null ]]
        then
            printf "\nUSE_LOAD_BALANCER=false BUT failed to retrieve clusterIP for envoy NodePort service.\n"
            return 1
        else
            nodeport=$(kubectl get svc -n tanzu-system-ingress -o json | jq -r '.items[] | select(.spec.type == "NodePort" and .metadata.name == "envoy") | .spec.ports[0].nodePort')            
        fi
    else
        lbip=$(kubectl get svc -n tanzu-system-ingress -o json | jq -r '.items[] | select(.spec.type == "LoadBalancer" and .metadata.name == "envoy") | .status.loadBalancer.ingress[0].ip')
    fi
    
    if [[ -z $lbip || $lbip == null ]]
    then
        local lbhostname=$(kubectl get svc -n tanzu-system-ingress -o json | jq -r '.items[] | select(.spec.type == "LoadBalancer" and .metadata.name == "envoy") | .status.loadBalancer.ingress[0].hostname')
        printf "Available at Hostname: $lbhostname\n\n"
        if [[ -n $lbhostname ]]
        then
            echo "LB_HOSTNAME#$lbhostname" >> $HOME/configs/output
            sleep 1
            # lbip=$(dig $lbhostname +short)
            printf "Retrieving IP against hostname...\n"
            lbip=$(perl  -MSocket -MData::Dumper -wle'my @addresses = gethostbyname($ARGV[0]); my @ips = map { inet_ntoa($_) } @addresses[4 .. $#addresses]; print $ips[0]' -- "$lbhostname" | perl -pe 'chomp')
            sleep 1
            if [[ -n $lbip ]]
            then
                printf "IP for Hostname: $lbip\n\n"
                echo "GENERATEDLBIP#$lbip" >> $HOME/configs/output
                sleep 1
            else
                printf "WARN: IP for Hostname: $lbhostname....could not be retrieved.\n\n"
                sleep 5
            fi
        fi
    else
        printf "Available at IP: $lbip\n\n"
        echo "GENERATEDLBIP#$lbip" >> $HOME/configs/output
        sleep 1
        if [[ -n $nodeport ]]
        then
            printf "NodePort for IP: $nodeport\n\n"
            echo "GENERATEDNODEPORT#$nodeport" >> $HOME/configs/output
            sleep 1
            printf "\nTAP Ingress IP/NodePort: $lbip:$nodeport\n\n\n"
        else
            printf "\nTAP Ingress IP: $lbip\n\n\n"
        fi
        
        sleep 5
    fi  
}

updateWithNIPIO () {
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true


    local localProfileFileName=$1
    local localTAPPackageVersion=$2

    if [[ -z $localProfileFileName || $localProfileFileName == null ]]
    then
        if [[ -n $TAP_PROFILE_FILE_NAME ]]
        then
            localProfileFileName=$TAP_PROFILE_FILE_NAME
        else
            localProfileFileName=$HOME/configs/tap-values-generated.yaml
        fi
    fi

    if [[ -z $localTAPPackageVersion || $localTAPPackageVersion == null ]]
    then
        localTAPPackageVersion=$(tanzu package available list tap.tanzu.vmware.com --namespace tap-install -o json | jq -r '[ .[] | {version: .version, released: .["released-at"]|split(" ")[0]} ] | sort_by(.released) | reverse[0] | .version')
    fi

    printf "\n"
    printf "Checking presence of token generatedlbip in the TAP values file...\n"
    sleep 5
    local isgeneratedlbipexists=$(cat $localProfileFileName | grep generatedlbip)
    sleep 4
    local lbip=$(cat $HOME/configs/output | grep GENERATEDLBIP# | cut -d '#' -f2)
    if [[ -n $isgeneratedlbipexists && -n $lbip ]]
    then
        printf "Found generatedlbip token present in the tap values file. This indicates the users intention to use nip.io or xip.io\n"
        printf "replacing generatedlbip with $lbip...\n"
        local replaceText='generatedlbip'
        awk -v old=$replaceText -v new="$lbip" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $localProfileFileName > $localProfileFileName.tmp \
            && sleep 1 \
            && mv $localProfileFileName.tmp $localProfileFileName \
            && sleep 1 \
            && printf "Replace complete.\nExecuting tanzu package update...\n" \
            && tanzu package installed update tap -v $localTAPPackageVersion --values-file $localProfileFileName -n tap-install \
            && printf "\nwait 1m...\n" \
            && sleep 1m \
            && printf "Update complete.\n"
    else
        printf "use this ip to create A record in the DNS zone. Alternatively, if you do not have a deligated domain you can also use free $lbip.nip.io in which case you will need to update profile with it.\n"
        printf "To update run the below command:\n"
        printf "tanzu package installed update tap -v $localTAPPackageVersion --values-file $localProfileFileName -n tap-install\n"
    fi
}