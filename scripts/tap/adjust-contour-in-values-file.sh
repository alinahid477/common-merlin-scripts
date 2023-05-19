#!/bin/bash

addContourBlockAccordinglyInProfileFile()
{
    # new logic add: when it is K8s in AWS then add a different block for contour. https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-online-profile.html#full-profile-3
    # when not then add the regular block

    # if contour block already exists we do not want another.
    # if contour block already exists means user had put it in the file (so he/she must have done it correctly) OR 
    # it is backward compatibility of this script.
    local profilefilename=$1
    printf "\nDBG: profilefilename $profilefilename\n"
    if [[ -f $profilefilename ]]
    then
        
        local isexist=$(cat $profilefilename | grep -w 'contour:$')
        printf "\nDBG: isexist $isexist\n"
        if [[ -z $isexist ]]
        then
            printf "\nDBG: no countour\n"
            local isUseAWSNLB=''
            if [[ -n $USE_AWS_NLB && $USE_AWS_NLB == 'YES' ]]
            then
                isUseAWSNLB=$USE_AWS_NLB
            else
                local CONTEXT=$(kubectl config current-context)
                printf "\nDBG: context $CONTEXT\n"
                if [[ -n $CONTEXT ]]
                then
                    local CLUSTER=$(kubectl config view -o json | jq -r --arg context "$CONTEXT" '.contexts[] | select(.name == $context) | .context.cluster')
                    printf "\nDBG: context $CLUSTER\n"
                    if [[ -n $CLUSTER ]]
                    then
                        local isAWSEndPoint=$(kubectl config view -o json | jq -r --arg cluster "$CLUSTER" '.clusters[] | select(.name == $cluster) | .cluster.server' | grep 'amazonaws.')
                        printf "\nDBG: endpoint: $isAWSEndPoint\n"
                        if [[ -n $isAWSEndPoint ]]
                        then
                            isUseAWSNLB="YES"
                        fi
                    fi
                fi
            fi

            echo "" >> $profilefilename
            printf "\nisUseAWSNLB=$isUseAWSNLB\n"
            if [[ -n $isUseAWSNLB && $isUseAWSNLB == "YES" ]]
            then
                printf "\nDBG: cat $HOME/binaries/templates/tap-contour-block-aws.template >> $profilefilename\n"
                cat $HOME/binaries/templates/tap-contour-block-aws.template >> $profilefilename
            else
                printf "\nDBG: cat $HOME/binaries/templates/tap-contour-block-generic.template >> $profilefilename\n"
                cat $HOME/binaries/templates/tap-contour-block-generic.template >> $profilefilename
            fi
        fi
    fi    
}

# this file is getting called from WebUI interface. server.js-->writeToProfileFile-->../merlin/run-adjust-file.sh
addContourBlockAccordinglyInProfileFile $1