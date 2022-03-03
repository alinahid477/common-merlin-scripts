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
        

        # if there's a condition for display this block then first check if condition is met or not
        local andconditions_forblock=$(echo $(_jq '.andconditions_forblock'))
        local ret=255
        if [[ -n $andconditions_forblock && $andconditions_forblock != null ]]
        then
            andconditions_forblock=($(echo "$andconditions_forblock" | jq -rc '.[]')) # read as array
            checkConditionWithDefaultValueFile "AND" $defaultValuesFile ${andconditions_forblock[@]}
            ret=$? # 0 means checkCondition was true else 1 meaning check condition is false
            if [[ $ret == 1 ]]
            then
                # condition is false. skip this block as this does not apply. 
                # eg: if INFRASTRUCTURE_PROVIDER != vsphere then no reason to show options / input for networking
                # as for INFRASTRUCTURE_PROVIDER=aws || INFRASTRUCTURE_PROVIDER=azure it will most like use the cloud network LB instead of something like avi, nsxt
                continue
            fi
        fi


        local confirmed=''
        local promptName=$(echo $(_jq '.name')) # get property value of property called "name" from itemObject (aka array element object)
        local prompt=$(echo $(_jq '.prompt'))
        local hint=$(echo $(_jq '.hint'))
        local defaultoptionvalue=$(echo $(_jq '.defaultoptionvalue'))
        local defaultoptionkey=$(echo $(_jq '.defaultoptionkey'))
        local optionsJson=$(echo $(_jq '.options'))

        # value for $defaultoptionkey will take precedence over $defaultoptionvalue
        if [[ -n $defaultoptionkey && $defaultoptionkey != null ]]
        then
            local foundvalue=$(findValueForKey $defaultoptionkey $defaultValuesFile)
            if [[ -n $foundvalue && $foundvalue != null ]]
            then
                defaultoptionvalue=$foundvalue
            fi            
        fi

        # if there's a condition for default value then let;s check if condition is met or not
        local andconditions_forvalue=$(echo $(_jq '.andconditions_forblock'))
        ret=255
        if [[ -n $andconditions_forvalue && $andconditions_forvalue != null ]]
        then
            andconditions_forvalue=($(echo "$andconditions_forvalue" | jq -rc '.[]')) # read as array
            checkConditionWithDefaultValueFile "AND" $defaultValuesFile ${andconditions_forvalue[@]}
            ret=$? # 0 means checkCondition was true else 1 meaning check condition is false
            if [[ $ret == 1 ]]
            then
                # condition is false. So the defaultvalue cannot be used.
                defaultoptionvalue=''
            fi
        fi
        
         # when there's value for defaultoptionvalue then it will be confirmed='y' because in this case we dont need to take user input.
        if [[ -n $defaultoptionvalue && $defaultoptionvalue != null ]]
        then
            confirmed='y'
        fi

        # I gotten this far meaning show prompt to end-user
        if [[ -n $hint && $hint != null ]] 
        then
            printf "$prompt (${bluecolor} hint: $hint ${normalcolor})\n"
        else
            printf "$prompt\n"
        fi

       

        # when there's value for defaultoptionvalue then it will be confirmed='y' because in this case we dont need to take user input.
        # AND $optionsJson means need to type in value. So should not ask y/n.
        # OTHERWISE let's ask user if she/he like to select the file or not
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