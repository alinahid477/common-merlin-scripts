#!/bin/bash
test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
test -f $HOME/tokenfile && export $(cat $HOME/tokenfile | xargs) || true

source $HOME/binaries/scripts/contains-element.sh
source $HOME/binaries/scripts/tap/build-profile-file.sh
source $HOME/binaries/scripts/extract-and-take-input.sh
source $HOME/binaries/scripts/select-from-available-options.sh

generateProfile () {
    printf "\n*******Starting profile wizard*******\n\n"
    local templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)
    local profileTypes=("full" "lite" "iteration" "build" "run" "view" "customfile")
    local selectedProfileType=''
    local selectedProfileMainType=''
    selectFromAvailableOptions ${profileTypes[@]}
    ret=$?
    if [[ $ret == 255 ]]
    then
        printf "${redcolor}ERROR: No selection were made.${normalcolor}\n"
        returnOrexit || return 1
    else
        # selected option
        selectedProfileType=${profileTypes[$ret]}
        if [[ $selectedProfileType == 'customfile' || $selectedProfileType == 'full' || $selectedProfileType == 'iteration' || $selectedProfileType == 'build' || $selectedProfileType == 'run' || $selectedProfileType == 'view' ]]
        then
            selectedProfileMainType='full'
        else 
            if [[ $selectedProfileType == 'lite' ]]
            then
                selectedProfileMainType='lite'
            fi
        fi
    fi

    if [[ $selectedProfileType == 'customfile' ]]
    then
        local customprofilefile=''
        while [[ -z $customprofilefile ]]; do
            read -p "type full path of the custom profile file (eg: /root/configs/myfile.yaml): " customprofilefile
            if [[ -z $customprofilefile ]]
            then
                customprofilefile=''
            fi
            if [[ ! -f "$customprofilefile" ]]
            then
                customprofilefile=''
            fi
            if [[ -z $customprofilefile ]]
            then
                printf "${redcolor}Empty not allowed. You must provide a valid full path to the file.${normalcolor}\n"
            fi
        done
        if [[ -z $customprofilefile ]]
        then
            returnOrexit || return 1
        fi

        echo $customprofilefile >> $(echo $notifyfile)
    else
        local profilename=''
        while [[ -z $profilename ]]; do
            read -p "name of the profile: " profilename
            if [[ -z $profilename ]]
            then
                printf "empty value is not allowed.\n"
            fi
        done

        if [[ -n $DESCRIPTOR_NAME ]]
        then
            # export DESCRIPTOR_NAME=$(echo "$DESCRIPTOR_NAME-$selectedProfileMainType" | xargs)
            export DESCRIPTOR_NAME=$(echo $selectedProfileMainType | xargs)
            printf "\nAdjusted descriptor name DESCRIPTOR_NAME=$DESCRIPTOR_NAME...ok\n"
        fi

        export PROFILE_TYPE=$selectedProfileType
        printf "\ncreating temporary file for profile...."
        local tmpProfileFile=$(echo "/tmp/tap-profile-$profilename.yaml" | xargs)
        cp $templateFilesDIR/tap-profile-$selectedProfileType.template $tmpProfileFile && printf "ok." || printf "failed"
        printf "\n"

        if [[ $selectedProfileType == 'full' || $selectedProfileType == 'lite' ]]
        then
            printf "generate profile file...\n"
            buildProfileFile $tmpProfileFile
            printf "\nprofile file generation...COMPLETE.\n"

            printf "\n\n\n"
        fi

        extractVariableAndTakeInput $tmpProfileFile
        printf "\nprofile value adjustment...COMPLETE\n"

        printf "\nadding file for confirmation..."
        cp $tmpProfileFile $HOME/configs/ && printf "COMPLETE" || printf "FAILED"

        printf "\n\nGenerated profile file: $HOME/configs/tap-profile-$profilename.yaml\n\n"
        echo "$HOME/configs/tap-profile-$profilename.yaml" >> $(echo $notifyfile)
    fi

    
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