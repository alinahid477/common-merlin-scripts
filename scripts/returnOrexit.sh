#!/bin/bash

returned='n'
function returnOrexit()
{
    returned='n'
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        returned='y'
        return 1 # very important. return 1 means error. return 0 means success.
    else
        exit
    fi
}