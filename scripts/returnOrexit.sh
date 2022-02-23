#!/bin/bash

returned='n'
function returnOrexit1()
{
    returned='n'
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        returned='y'
        printf "\nreturn 1\n"
        return 1
    else
        exit
    fi
}