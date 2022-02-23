#!/bin/bash

source $HOME/binaries/scripts/contains-element.sh

function selectFromAvailableOptions () {
    # param #1: expects an array
    local availableOptions=("$@")

    # if empty or count is less than 1
    if [[ -z $availableOptions || ${#availableOptions[@]} -lt 1 ]]
    then
        returnOrexit || return ''
    fi
    local optionSTR=''
    # need to convert into comma separated string just so I can display
    for option in "${availableOptions[@]}"; do
        if [[ -z $optionSTR ]]
        then
            optionSTR=$option
        else
            optionSTR=$(echo "$optionSTR,$option")
        fi
    done
    optionSTR=$(echo "$optionSTR,none")

    printf "available options are: [$optionSTR]\n"
    local selectedOption=''
    local selectedOptionIndex=255
    while [[ -z $selectedOption ]]; do
        read -p "type the appropriate option: " selectedOption
        if [[ $selectedOption == 'none' ]]
        then
            printf "You selected none. Selected option is empty.\n"
            unset selectedOption
            break
        fi
        containsElement "$selectedOption" "${availableOptions[@]}"
        ret=$?
        if [[ $ret == 1 ]]
        then
            unset selectedOption
            printf "You must input a valid value from the available options.\n"
        else
            for i in "${!availableOptions[@]}"; do
                if [[ "${availableOptions[$i]}" = "${selectedOption}" ]];
                then
                    selectedOptionIndex=$i
                    break
                fi
            done
        fi
    done
    printf "Selected option: $selectedOption @ index $selectedOptionIndex\n"
    return $selectedOptionIndex
}