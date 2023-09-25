
adjustCACertDataInValuesFile() {
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    
    local profilefilename=$1
    if [[ -z $profilefilename ]]
    then
        profilefilename=$TAP_PROFILE_FILE_NAME
    fi
    if [[ -f $profilefilename ]]
    then
        local caCertDataPemFileStr=$(cat $profilefilename | grep "# caCertDataPEMFile:")
        if [[ -n $caCertDataPemFileStr ]]
        then
            local caCertDataPemFilePath=$(echo $caCertDataPemFileStr | rev | cut -d: -f1 | rev)
            if [[ -n $caCertDataPemFilePath && $caCertDataPemFilePath == *"/"* ]]
            then
                
                printf "\nDetected pem file for shared.ca_cert_data. Adjusting $profilefilename to add ca_cert_data...\n"
                local pemFileContent=$(cat $caCertDataPemFilePath | while read line; do echo "    ${line}"; done)
                if [[ -n $pemFileContent ]]
                then
                    local replaceStr="ca_cert_data: |\n$pemFileContent"
                    awk -v old=#__ca_cert_data -v new="$replaceStr" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $profilefilename > $profilefilename.tmp && mv $profilefilename.tmp $profilefilename
                    printf "DONE.\n"
                fi
            fi
        fi
    fi
}
adjustCACertDataInValuesFile $1