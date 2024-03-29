#!/bin/bash
test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

addContourBlockAccordinglyInProfileFile()
{
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    # new logic add: when it is K8s in AWS then add a different block for contour. https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-online-profile.html#full-profile-3
    # when not then add the regular block

    # if contour block already exists we do not want another.
    # if contour block already exists means user had put it in the file (so he/she must have done it correctly) OR 
    # it is backward compatibility of this script.
    local profilefilename=$1
    if [[ -z $profilefilename ]]
    then
        profilefilename=$TAP_PROFILE_FILE_NAME
    fi
    if [[ -f $profilefilename ]]
    then
        
        local isexistpn=$(cat $profilefilename | grep -w 'contour:$')
        if [[ -z $isexistpn ]]
        then

            if [[ -n $INGRESS_TYPE && $INGRESS_TYPE == 'NodePort' ]]
            then
                if [[ -n $NODEPORT_HTTP_PORT && -n $NODEPORT_HTTPS_PORT ]]
                then
                    local portValues="\n      nodePorts:\n        http: $NODEPORT_HTTP_PORT\n        https: $NODEPORT_HTTPS_PORT\n"
                    cp $HOME/binaries/templates/tap-contour-block-nodeport.template /tmp/tap-contour-block-nodeport.template.tmp
                    printf "$portValues" >> /tmp/tap-contour-block-nodeport.template.tmp
                    cat /tmp/tap-contour-block-nodeport.template.tmp >> $profilefilename
                else
                    cat $HOME/binaries/templates/tap-contour-block-nodeport.template >> $profilefilename
                fi
            else
                local isUseAWSNLB=''
                if [[ -n $USE_AWS_NLB && $USE_AWS_NLB == 'YES' ]]
                then
                    isUseAWSNLB=$USE_AWS_NLB
                else
                    local CONTEXT=$(kubectl config current-context)
                    if [[ -n $CONTEXT ]]
                    then
                        local CLUSTER=$(kubectl config view -o json | jq -r --arg context "$CONTEXT" '.contexts[] | select(.name == $context) | .context.cluster')
                        if [[ -n $CLUSTER ]]
                        then
                            local isAWSEndPoint=$(kubectl config view -o json | jq -r --arg cluster "$CLUSTER" '.clusters[] | select(.name == $cluster) | .cluster.server' | grep 'amazonaws.')
                            if [[ -n $isAWSEndPoint ]]
                            then
                                isUseAWSNLB="YES"
                            fi
                        fi
                    fi
                fi

                echo "" >> $profilefilename
                if [[ -n $isUseAWSNLB && $isUseAWSNLB == "YES" ]]
                then
                    cat $HOME/binaries/templates/tap-contour-block-aws.template >> $profilefilename
                else
                    cat $HOME/binaries/templates/tap-contour-block-loadbalancer.template >> $profilefilename
                fi
            fi

            
        fi
    fi    
}

# this file is getting called from WebUI interface. server.js-->writeToProfileFile-->../merlin/run-adjust-file.sh
addContourBlockAccordinglyInProfileFile $1