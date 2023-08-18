#!/bin/bash
test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

adjustExcludedPackage()
{
    # this will work if the tap-values file container a signature #__MERLIN_PH_EXCLUDE_PACKAGE_NAME
    # the tap-values file template in TAP-Jumpstart UI contains this signature.

    local profilefilename=$1
    local packageToExclude=$2
    
    if [[ -f $profilefilename && -n $packageToExclude ]]
    then
        
        local isexistpn=$(cat $profilefilename | grep -w 'excluded_packages:$' || true)
        if [[ -n $isexistpn ]]
        then
            local isexistplaceholder=$(cat $profilefilename | grep -w '#__MERLIN_PH_EXCLUDE_PACKAGE_NAME$' || true)
            if [[ -n $isexistplaceholder ]]
            then
                local replaceStr="- $packageToExclude\n  #__MERLIN_PH_EXCLUDE_PACKAGE_NAME"
                awk -v old=#__MERLIN_PH_EXCLUDE_PACKAGE_NAME -v new="$replaceStr" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $profilefilename > $profilefilename.tmp && mv $profilefilename.tmp $profilefilename
            fi
        fi
    fi    
}

# this file is getting called from installtapprofile.sh
#    during the installaion process it checks whether kustomize is intalled by TMC or not...
#    if it is then exclude fluxcd 
# $1=/path/to/tap-values.yaml
# $2=package to exclude
adjustExcludedPackage $1 $2