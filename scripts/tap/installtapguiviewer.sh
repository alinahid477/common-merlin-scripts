#!/bin/bash

# test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

installTAPGuiViewer() {
    printf "\n\nCreating TAP GUI Viewer in namespace: tap-gui...\n\n"
    sleep 3
    kubectl apply -f $HOME/binaries/templates/tap-gui-viewer-service-account-rbac.yaml

    printf "\nRetrieving cluster url and token...\n"
    sleep 3
    local clusterUrl=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    local clusterToken=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json | jq -r '.data["token"]' | base64 --decode)
    printf "\n- ClusterURL: $clusterUrl\n- ClusterTOKEN: $clusterToken...\n"
    
    printf "\n\nSaving in output file...."
    echo CLUSTER_URL#$clusterUrl >> $HOME/configs/output
    echo CLUSTER_TOKEN#$clusterToken >> $HOME/configs/output
    
    sleep 1
    printf "COMPLETE.\n\n"
}