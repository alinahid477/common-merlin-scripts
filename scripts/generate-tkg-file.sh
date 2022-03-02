#!/bin/bash
export $(cat /root/.env | xargs)

templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)


source $HOME/binaries/scripts/contains-element.sh
source $HOME/binaries/scripts/assemble-file.sh
source $HOME/binaries/scripts/extract-and-take-input.sh

generateTKCFile () {
    local bluecolor=$(tput setaf 4)
    local magentacolor=$(tput setaf 5)
    local normalcolor=$(tput sgr0)

    local tkgClusterName=''
    while [[ -z $tkgClusterName ]]; do
        read -p "Cluster Name: " name
        if [[ -z $tkgClusterName ]]
        then
            printf "empty value is not allowed.\n"
        fi
    done

    export CLUSTER_NAME=$tkgClusterName

    local clusterconfigfile=''
    local clusterconfigfilepath="$HOME/.config/tanzu/tkg/clusterconfigs"
    printf "\nLooking for management cluster config file in $clusterconfigfilepath/"
    printf "\n${magentacolor}note: the management cluster config file act as a default value provider for TKG cluster config.${normalcolor}\n"
    local numberofyamlfound=$(find $clusterconfigfilepath/*.yaml -type f -printf "." | wc -c)
    if [[ $numberofyamlfound -gt 1 ]]
    then
        readarray -t yamlfiles < <(ls -1 $clusterconfigfilepath) 
        ls -1 $clusterconfigfilepath
        printf "\nFound more than 1 files. Need user input to pick one..."
        printf "\n${magentacolor}Type \"none\" to not pick any file${normalcolor}"
        printf "\n${magentacolor}note: not having a management cluster config file will prompt for a lot of input for TKG cluster config.${normalcolor}"
        printf "\n"
        while [[ -z $clusterconfigfile ]]; do
            read -p "type the name of the file: " clusterconfigfile
            if [[ -z $clusterconfigfile ]]
            then
                printf "You must provide a name.\n"
            else
                if [[ $clusterconfigfile == 'none' ]]
                then
                    clusterconfigfile=''
                    break
                fi
                containsElement "$clusterconfigfile" "${yamlfiles[@]}"
                ret=$?
                if [[ $ret == 1 ]]
                then
                    clusterconfigfile=''
                fi
            fi
        done
    else
        clusterconfigfile=$(ls $clusterconfigfilepath/*.yaml)
    fi
    
    if [[ -n $clusterconfigfile ]]
    then
        clusterconfigfile="$clusterconfigfilepath/$clusterconfigfile"
        printf "${bluecolor}Found management cluster config file: $clusterconfigfilepath/$clusterconfigfile${normalcolor}"
        local confirmation=''
        while true; do
            read -p "Confirm to use the above as default value provider [y/n]: " yn
            case $yn in
                [Yy]* ) confirmation="y"; printf "you confirmed yes\n"; break;;
                [Nn]* ) confirmation="n";printf "You confirmed no.\n"; break;;
                * ) echo "Please answer y or n.";;
            esac
        done
        if [[ $confirmation == 'n' ]]
        then
            printf "Not using management cluster config file as default value provider.\n"
            clusterconfigfile=''
        fi
    fi


    printf "\ncreating temporary file...."
    tmpTKCFile=$(echo "/tmp/tkg-$tkgClusterName.yaml" | xargs)
    cp $templateFilesDIR/basetkc.template $tmpTKCFile && printf "ok." || printf "failed"
    printf "\n"

    printf "generate TKG file...\n"
    assembleFile $tmpTKCFile $clusterconfigfile || returnOrexit || return 1
    printf "\nTKG file generation...COMPLETE.\n"


    printf "\n\n\n"

    printf "\npopulate TKG file...\n"
    extractVariableAndTakeInput $tmpTKCFile $clusterconfigfile || returnOrexit || return 1
    printf "\nprofile value adjustment...COMPLETE\n"

    printf "\nadding file for confirmation..."
    cp $tmpTKCFile $HOME/workload-clusters/ && printf "COMPLETE" || printf "FAILED"

    printf "\n\nGenerated tkg workload-cluster config file: $HOME/workload-clusters/tkg-$tkgClusterName.yaml\n\n"

    return 0
}

# generateProfile

# debug

# profilename="debug"
# profiletype="full"
# printf "\ncreating temporary file for profile...."
# tmpProfileFile=$(echo "/tmp/profile-$profilename.yaml" | xargs)
# cp $templateFilesDIR/profile-$profiletype.template $tmpProfileFile && printf "ok." || printf "failed"
# printf "\n"
# buildProfileFile $tmpProfileFile
# end debug