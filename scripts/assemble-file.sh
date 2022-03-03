#!/bin/bash
export $(cat /root/.env | xargs)

source $HOME/binaries/scripts/contains-element.sh
source $HOME/binaries/scripts/select-from-available-options.sh
source $HOME/binaries/scripts/keyvaluefile-functions.sh

# read what to prompt for user input from a json file.
function assembleFile () {
    local templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)
    local promptsForFilesJSON='prompts-for-files.json'
    local yellowcolor=$(tput setaf 3)
    local bluecolor=$(tput setaf 4)
    local normalcolor=$(tput sgr0)

    local baseFile=$1
    local defaultValuesFile=$2

    # iterate over array in json file (json file starts with array)
    # base64 decode is needed so that jq format is per line. Otherwise gettting value from the formatted item object becomes impossible 
    for promptItem in $(jq -r '.[] | @base64' $templateFilesDIR/$promptsForFilesJSON); do
        printf "\n\n"

        _jq() {
            echo ${promptItem} | base64 --decode | jq -r ${1}
        }
        unset confirmed
        local promptName=$(echo $(_jq '.name')) # get property value of property called "name" from itemObject (aka array element object)
        local prompt=$(echo $(_jq '.prompt'))
        local hint=$(echo $(_jq '.hint'))
        local defaultoptionvalue=$(echo $(_jq '.defaultoptionvalue'))
        local defaultoptionkey=$(echo $(_jq '.defaultoptionkey'))
        local optionsJson=$(echo $(_jq '.options'))

        if [[ -n $hint && $hint != null ]] 
        then
            printf "$prompt (${bluecolor} hint: $hint ${normalcolor})\n"
        else
            printf "$prompt\n"
        fi

        # if there's a value for 'defaultoptionvalue' then check condition. 
        # If condition is true take the 'defaultoptionvalue'.
        # If condition is false take user input

        if [[ -n $defaultoptionvalue && $defaultoptionvalue != null ]] # so, -n works if variable does not exist or value is empty. the jq is outputing null hence need to check null too.
        then
            local andconditions=$(echo $(_jq '.andconditions'))
            local ret=1
            if [[ -n $andconditions && $andconditions != null ]]
            then
                andconditions=($(echo "$andconditions" | jq -rc '.[]')) # read as array
                checkConditionWithDefaultValueFile "AND" $defaultValuesFile ${andconditions[@]}
                ret=$? # 0 means checkCondition was true else 1 meaning check condition is false
            fi

            if [[ $ret == 1 ]]
            then
                # condition is false. Hence empty 'defaultoptionvalue' so that I can take user input.
                defaultoptionvalue=''
            else
                # condition is true. Hence use 'defaultoptionvalue' instead of prompting for user input.
                confirmed='y'
            fi
        fi
        
        # If there's no $defaultoptionvalue (either condition did not meet OR isnt specified in json)
        #   we want to check the $defaultoptionkey and extract the value for it. which will be treated as $defaultoptionvalue
        # The goal here is to get a default value for the prompt.
        if [[ (( -z $defaultoptionvalue || $defaultoptionvalue == null )) && -n $defaultoptionkey && $defaultoptionkey != null ]]
        then
            local tmp=$(findValueForKey $defaultoptionkey $defaultValuesFile)
            if [[ -n $tmp && $tmp != null ]]
            then
                # so, since we have a default value, we do not need to prompt user for it
                defaultoptionvalue=$tmp
                confirmed='y'
            fi
        fi
        # when there's value for defaultoptionvalue then it will be confirmed='y' because in this case we dont need to take user input.
        # as we already have 'defaultoptionvalue' it is confirmed='y'
        # AND $optionsJson means need to type in value. So should not ask y/n.
        if [[ -z $confirmed && ((-z $optionsJson || $optionsJson == null)) ]]
        then
            while true; do
                read -p "please confirm [y/n]: " yn
                case $yn in
                    [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                    [Nn]* ) printf "You said no.\n"; break;;
                    * ) echo "Please answer y or n\n";;
                esac
            done
        fi
        
        if [[ $confirmed == 'y' ]]
        then
            filename=$(echo $(_jq '.filename'))

            local selectedOption=''
            if [[ -n $defaultoptionvalue && $defaultoptionvalue != null ]]
            then                
                # we only use optionJson if we want to take user input and 
                # we will only take user input from options if there's no value for $defaultoptionvalue.
                # since this (inside this if) means that there's $defaultoptionvalue so we will set if to empty for the next if below.
                optionsJson=''
                
                # if we have value for $defaultoptionvalue we will do selectedOption=$defaultoptionvalue instead.
                selectedOption=$defaultoptionvalue
                printf "No need for user input. Using extracted default: ${yellowcolor}$defaultoptionvalue${normalcolor}.\n"
            fi
            
            if [[ -n $optionsJson && $optionsJson != null ]]
            then
                # this means I have read $optionsJson as there was no $defaultoptionvalue
                # no prompt use to select an option from optionsJson

                # read it as array so I can perform containsElement for valid value from user input.
                readarray -t options < <(echo $optionsJson | jq -rc '.[]')

                if [[ ${#options[@]} -gt 1 ]]
                then
                    # prompt user to select 1
                    
                    selectFromAvailableOptions ${options[@]}
                    ret=$?
                    if [[ $ret == 255 ]]
                    then
                        printf "\nERROR: Invalid option selected.\n"
                        returnOrexit || return 1
                    else
                        selectedOption=${options[$ret]}
                    fi
                else    
                    # only 1 option available. No point presenting with prompt
                    selectedOption="${options[0]}"
                    printf "No need for user input as only 1 option is available: $selectedOption\n"
                fi

            fi


            if [[ -n $selectedOption && -n $filename ]]
            then
                # when multiple options exists (eg: vsphere or aws or azure)
                # I have mentioned the filename in the JSON prompt file in this format $.template
                # AND the physical file exists with name vsphere.template, azure.template etc
                # Thus based on the input from user or defaultoptionvalue (eg: vsphere or azure or aws)
                #   I will dynamically form the filename eg: replace the '$' sign with selectedOption 
                #   eg: filename='$.template' will become filename='vsphere.template' 
                filename=$(echo $filename | sed 's|\$|'$selectedOption'|g')
            fi

            if [[ -n $filename && $filename != null ]]
            then
                # append the content of the chunked file to the profile file.
                printf "adding configs for $promptName...."
                cat $templateFilesDIR/$filename >> $baseFile && printf "ok." || printf "failed."
                printf "\n\n" >> $baseFile
            fi
            printf "\n"
        fi
    done

    return 0
}