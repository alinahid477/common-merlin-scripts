#!/bin/bash
adjustStorageClassName()
{
    # this will work if the tap-values file container a signature #__MERLIN_PH_EXCLUDE_PACKAGE_NAME
    # the tap-values file template in TAP-Jumpstart UI contains this signature.

    local profilefilename=$1
    local storageClassName=$2
    
    if [[ -f $profilefilename && -n $storageClassName ]]
    then
        
        local isexistpn=$(cat $profilefilename | grep -w 'metadata_store:$' || true)
        if [[ -n $isexistpn ]]
        then
            local isexistplaceholder=$(cat $profilefilename | grep -w '#__metadata_store_storage_class_name$' || true)
            if [[ -n $isexistplaceholder ]]
            then
                local replaceStr="storage_class_name: $storageClassName"
                awk -v old=#__metadata_store_storage_class_name -v new="$replaceStr" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $profilefilename > $profilefilename.tmp && mv $profilefilename.tmp $profilefilename
            fi
        fi
    fi    
}

# this file is getting called from installtapprofile.sh
#    during the installaion process it checks if there exists an environment variable called METADATA_STORE_STORAGE_CLASS_NAME
#    it indicates whether the user wants to specifically specify a storageclass name to be uses (not just default storage).
#       This is a valid case for onprem vsphere based TKG2 when there is no default storage defined.
#    if it is then replace the placeholder with the value supplied.
# $1=/path/to/tap-values.yaml
# $2=metadata store storage class name
adjustStorageClassName $1 $2