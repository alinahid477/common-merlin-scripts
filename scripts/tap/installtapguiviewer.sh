#!/bin/bash

# test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

installTAPGuiViewer() {
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    printf "\nChecking K8s version..."
    local k8sversion=0
    if [[ -z $K8S_VERSION ]]
    then
        k8sversion=$(kubectl version --short --output=json 2>&1 | grep -i -v "Warn" | grep -i -v "Deprecat" | jq -rj '.serverVersion | [.major, .minor] | join(".")' | sed -e 's/[+-]//')        
    else
        k8sversion=$K8S_VERSION
    fi
    printf "$k8sversion\n"

    sleep 3
    printf "\nChecking for existing Secret:tap-gui-viewer  in namespace: tap-gui..."
    local isexistsGuiViewer=''
    if [[ -n $k8sversion && $k8sversion < 1.24 ]]
    then
        isexistsGuiViewer=$(kubectl -n tap-gui get sa tap-gui-viewer --ignore-not-found=true | grep -w tap-gui-viewer 2>/dev/null || true)
    else
        isexistsGuiViewer=$(kubectl -n tap-gui get secret tap-gui-viewer --ignore-not-found=true | grep -w tap-gui-viewer 2>/dev/null || true)
    fi
    
    if [[ -z $isexistsGuiViewer ]]
    then
        printf "NOT FOUND.\n\n"
        printf "Creating TAP GUI Viewer in namespace: tap-gui...\n"
        sleep 3
        kubectl apply -f $HOME/binaries/templates/tap-gui-viewer-service-account-rbac.yaml
        if [[ -n $k8sversion && $k8sversion < 1.24 ]]
        then
            printf "\nK8s version is NOT 1.24 or above. No need to create aditional secret for sa: tap-gui-viewer.\n"
        else
            printf "\nK8s version is 1.24 or above. Creating secret tap-gui-viewer for sa: tap-gui-viewer.\n"
            kubectl apply -f $HOME/binaries/templates/tap-gui-viewer-service-account-secret.yaml
        fi
        printf "create tap-gui-viewer...COMPLETE.\n\n"
    else
        printf "FOUND.\n\n"
    fi
    printf "\nRetrieving cluster url and token...\n"
    sleep 3
    local clusterUrl=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    local clusterToken=''
    if [[ -n $k8sversion && $k8sversion < 1.24 ]]
    then
        clusterToken=$(kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui-viewer -o=json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode)
    else
        clusterToken=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json | jq -r '.data["token"]' | base64 --decode)
    fi
    
    printf "\n- ClusterURL: $clusterUrl\n- ClusterTOKEN: $clusterToken...\n"
    
    printf "\n\nSaving in output file...."
    echo CLUSTER_URL#$clusterUrl >> $HOME/configs/output
    echo CLUSTER_TOKEN#$clusterToken >> $HOME/configs/output
    
    sleep 1
    printf "COMPLETE.\n\n"
}