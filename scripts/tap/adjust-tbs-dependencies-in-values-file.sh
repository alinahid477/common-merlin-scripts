#!/bin/bash
adjustTBSDependencies()
{
    # this is for installing TAP with tbs: full
    # for now (as of 29/09/2023) this script will get called for airgap from installtapprofile.sh
    #   if there exists AIRGAP_TBS_PACKAGES_TAR.
    # AIRGAP_TBS_PACKAGES_TAR is set in the env file by Jumpstart GUI.

    local profilefilename=$1
    
    if [[ -f $profilefilename ]]
    then
        local isexistplaceholder=$(cat $profilefilename | grep -w '#__exclude_dependencies$' || true)
        if [[ -n $isexistplaceholder ]]
        then
            local replaceStr="exclude_dependencies: true"
            awk -v old=#__exclude_dependencies -v new="$replaceStr" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $profilefilename > $profilefilename.tmp && mv $profilefilename.tmp $profilefilename
        fi
    fi    
}

# this file is getting called from installtapprofile.sh
#    during the installaion process it checks if there exists an environment variable called AIRGAP_TBS_PACKAGES_TAR
# $1=/path/to/tap-values.yaml
adjustTBSDependencies $1