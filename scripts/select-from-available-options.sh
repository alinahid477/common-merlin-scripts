#!/bin/bash

source $HOME/binaries/scripts/contains-element.sh


function getOptionsInString () {
    local additionalOption=$1
    shift
    local availableOptions=("$@")
    
    local optionSTR=''
    # need to convert into comma separated string just so I can display
    for option in "${availableOptions[@]}"; do
        if [[ -z $option ]] 
        then
            continue
        fi

        if [[ -z $optionSTR ]]
        then
            optionSTR=$option
        else
            optionSTR=$(echo "$optionSTR, $option")
        fi
    done
    if [[ -n $additionalOption ]]
    then
        optionSTR=$(echo "$optionSTR, $additionalOption")
    fi
    
    printf "$optionSTR"
}


function selectFromAvailableOptionsWithDefault () {
    
    # param #1: expects an array
    local noneOrDefault=$1 # must be a value. If no default value is needed then pass none. Passing a default value will allow pressing enter to accept default value.
    shift
    local availableOptions=("$@")
    
    # if empty or count is less than 1
    if [[ -z $availableOptions || ${#availableOptions[@]} -lt 1 ]]
    then
        returnOrexit || return 255
    fi
    
    local optionSTR=$(getOptionsInString '' ${availableOptions[@]})

    printf "${yellowcolor}available options are: [$optionSTR]\n${normalcolor}"
    printf "${yellowcolor}Type \"none\" for no selection.\n${normalcolor}"
    if [[ -n $noneOrDefault && $noneOrDefault != 'none' ]]
    then
        printf "${greencolor}Press enter to accept Default: $noneOrDefault${normalcolor}\n"
    fi
    local selectedOption=''
    local selectedOptionIndex=255
    while [[ -z $selectedOption ]]; do
        read -p "type the appropriate option: " selectedOption
        if [[ $selectedOption == 'none' ]]
        then
            printf "You selected none. Selected option is empty.\n"
            unset selectedOption
            break
        else
            if [[ -z $selectedOption && $noneOrDefault != 'none' ]]
            then
                # allow 'press enter to accept default'
                printf "Selecting default: $noneOrDefault...\n"
                selectedOption=$noneOrDefault
            fi
        fi
        containsElement "$selectedOption" "${availableOptions[@]}"
        ret=$?
        if [[ $ret == 1 ]]
        then
            unset selectedOption
            printf "${redcolor}error: You must input a valid value from the available options. try again..${normalcolor}\n"
        else
            for i in "${!availableOptions[@]}"; do
                if [[ "${availableOptions[$i]}" == "${selectedOption}" ]]
                then
                    selectedOptionIndex=$i
                    break
                else
                    local availableOptions1=$(echo "${availableOptions[$i]}" | xargs) 
                    local selectedOption1=$(echo "${selectedOption}" | xargs)
                    if [[ "$availableOptions1" == "$selectedOption1" ]]
                    then
                        selectedOptionIndex=$i
                        break
                    fi
                fi
            done
        fi
    done
    printf "${greencolor}Selected option: $selectedOption${normalcolor}\n"
    return $selectedOptionIndex
}

function selectFromAvailableOptions () {
    local availableOptions=("$@")
    selectFromAvailableOptionsWithDefault "none" ${availableOptions[@]}
}