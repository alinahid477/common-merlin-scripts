#!/bin/bash


returned='n'
returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        returned='y'
        return
    else
        exit
    fi
}

source $HOME/binaries/scripts/contains-element.sh

unset selectedOption
function selectFromAvailableOptions () {
    # param #1: expects an array
    local availableOptions=$1

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
    while [[ -z $selectedOption ]]; do
        read -p "type the appropriate option: " selectedOption
        if [[ $selectedOption == 'none' ]]
        then
            printf "You selected none. Selected option is empty.\n"
            unset selectedOption
            returnOrexit || return ''
        fi
        containsElement "${selectedOption}" "${options[@]}"
        ret=$?
        if [[ $ret == 0 ]]
        then
            unset selectedOption
            printf "You must input a valid value from the available options.\n"
        fi
    done
    printf "Selected option: $selectedOption\n"
    return $selectedOption
}