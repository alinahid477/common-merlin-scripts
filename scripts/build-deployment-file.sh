#!/bin/bash
export $(cat /root/.env | xargs)

source $HOME/binaries/scripts/contains-element.sh
source $HOME/binaries/scripts/select-from-available-options.sh


function findValueForKey () {
    local key=$1
    if [[ -z $key ]]
    then
        return 1
    fi
    # check if the value exists in environment variable
    if [[ -z ${!key} ]]
    then
        # not found in environment variable
        # fallback to check in keyValueFile (file path supplied as argument)
        if [[ -n $keyValueFile ]]
        then
            # if keyValueFile supplied then read the file
            # and check if key matches.
            # if key matches then check if value matches

            while IFS=: read -r fkey fval # keyValueFile contains in this format "key: value" in evey line. TKGm clusterconfig file.
            do
                if [[ $fkey == $key ]]
                then
                    # keyValueFile file contains the key
                    x=$(echo $fval | sed 's,^ *,,; s, *$,,')
                    printf "$x"
                    break
                fi
            done < "$keyValueFile"
        fi
    else
        # found in environment variable
        printf "${!key}"
    fi
}

function checkCondition () { # returns 0 if condition is met. Otherwise returns 1.

    local conditionType=$1  # (Required) possible values are either 'AND' or 'OR'
    local conditionsJson=$2 # (Required) comma separated json string
    local keyValueFile=$3   # (Optional) filepath of the keyvalue file (single or multiple lines containing format 'key: value'. eg: tkgm clusterconfig file)


    if [[ -z $conditionType || -z $conditionsJson || $conditionsJson == null ]] # sincce conditionsJson is extracted from json it can be null. 
    then
        returnOrexit || return 1
    fi


    readarray -t conditions < <(echo $conditionsJson | jq -rc '.[]')
    

    local istrue=''
    for condition in ${conditions[@]}; do
        local keyvalpair=(${condition//=/ }) # string split by delim '='
        local key=${keyvalpair[0]}
        local val=${keyvalpair[1]}

        # value will be found either in environment variable OR in keyvaluefile.
        # environment variable takes precidence over value found in keyvaluefile

        # lets extract the value first
        local foundval=$(findValueForKey $key)
       

        if [[ $conditionType == 'AND' ]]
        then
            istrue='y'
            # after all it is an 'AND condition'. Hence, if as long as value for 1 key is missing or value does not match the condition is false.
            if [[ -z $foundval || $foundval != $val ]]
            then
                # only 1 'n' makes the AND condition false
                istrue='n'
                break
            fi
        fi

        if [[ $conditionType == 'OR' ]]
        then
            istrue='n'
            
            # As long as there's value for 1 key is present and it matches the contidion is true.
            # we only need set it to 'n' once when it is empty. because it is OR condition. Hence, if I get 'y' once then the condition is true.
            if [[ -n $foundval && $foundval == $val ]]
            then
                # only 1 'y' makes the OR condition true.
                istrue='y'
                break                
            fi
        fi
    done

    if [[ $istrue == 'y' ]]
    then
        return 0
    fi

    return 1
}


# read what to prompt for user input from a json file.
function assembleFile () {
    local templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)
    local promptsForFilesJSON='prompts-for-files.json'
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
        promptName=$(echo $(_jq '.name')) # get property value of property called "name" from itemObject (aka array element object)
        prompt=$(echo $(_jq '.prompt'))
        hint=$(echo $(_jq '.hint'))
        defaultoptionvalue=$(echo $(_jq '.defaultoptionvalue'))
        defaultoptionkey=$(echo $(_jq '.defaultoptionkey'))

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
            andconditionsJson=$(echo $(_jq '.andconditions'))
        
            checkCondition "AND" $andconditionsJson $defaultValuesFile
            ret=$? # 0 means checkCondition was true else 1 meaning check condition is false

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
            local tmp=$(findValueForKey $defaultoptionkey)
            if [[ -n $tmp && $tmp != null ]]
            then
                # so, since we have a default value, we do not need to prompt user for it
                defaultoptionvalue=$tmp
                confirmed='y'
            fi
        fi
        # when there's value for defaultoptionvalue then it will be confirmed='y' because in this case we dont need to take user input.
        # as we already have 'defaultoptionvalue' it is confirmed='y'
        if [[ -z $confirmed ]]
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
            local optionsJson=''
            if [[ -z $defaultoptionvalue || $defaultoptionvalue == null ]]
            then
                # we only need read optionJson if we want to take user input and 
                # we will only take user input from options if there's no value for $defaultoptionvalue.
                
                optionsJson=$(echo $(_jq '.options'))
            else
                # if we have value for $defaultoptionvalue we will do selectedOption=$defaultoptionvalue instead.
                selectedOption=$defaultoptionvalue
                printf "No need for user input. Using extracted default option value: $defaultoptionvalue instead from environment variable or cluster config.\n"
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
                    # only 1 context. Most likely the most usual.
                    selectedOption="${options[0]}"
                    printf "No need for user input as only 1 option is available: $selectedOption"
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