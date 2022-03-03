#!/bin/bash
export $(cat /root/.env | xargs)

function findValueForKey () {
    local key=$1
    local keyValueFile=$2
    
    if [[ -z $key ]]
    then
        return 1
    fi

    # environment variable takes precidence over value found in keyvaluefile
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

function checkConditionWithDefaultValueFile () { # returns 0 if condition is met. Otherwise returns 1.

    local conditionType=$1  # (Required) possible values are either 'AND' or 'OR'
    local keyValueFile=$2   # (Required, cause the next required param is array) filepath of the keyvalue file (single or multiple lines containing format 'key: value'. eg: tkgm clusterconfig file)
    shift
    shift
    local conditions=("$@") # (Required) comma separated json string
    
    if [[ $keyValueFile == 'na' ]] # Making the keyValueFile optional. When no keyValueFile exist pass 'na'
    then
        keyValueFile=''
    fi

    if [[ -z $conditionType || -z $conditions || $conditions == null || ${#conditions[@]} -lt 1 ]] # sincce conditionsJson is extracted from json it can be null. 
    then
        return 1
    fi
    
    local istrue=''
    for condition in ${conditions[@]}; do
        local keyvalpair=(${condition//=/ }) # string split by delim '='
        local key=${keyvalpair[0]}
        local val=${keyvalpair[1]}

        # value will be found either in environment variable OR in keyvaluefile.
        # lets extract the value first
        local foundval=$(findValueForKey $key $keyValueFile)
        
        if [[ $conditionType == 'AND' ]]
        then
            istrue='y'
            # after all it is an 'AND condition'. Hence, if as long as value for 1 key is missing or value does not match the condition is false.
            # the reason for (( -n $val && $foundval != $val )) is: sometimes the andconditions could be [ "SOME_KEY" ] and NOT [ "SOME_KEY=SOME_VAL" ].
            # When it is only [ "SOME_KEY" ] the $val will be empty, which means, the condition is "if there exists a value for "SOME_KEY" I am all good, I dont care what value."
            # BUT WHEN it is [ "SOME_KEY=SOME_VAL" ] I care about the key and matching the value too, eg: must be $foundval=SOME_VAL
            if [[ -z $foundval ]]
            then
                # only 1 'n' makes the AND condition false
                istrue='n'
                break
            fi
            if [[ -n $val && $foundval != $val ]]
            then
                istrue='n'
                # should be able break here. BUT sometime it can also be this scenario "true" != true --> which not what I want. So doing below additional check.
                foundval=$(echo $foundval | xargs) # remove quote marks from both side
                val=$(echo $val | xargs) # remove quote marks from both side
                if [[ $foundval == $val ]]
                then
                    # this means the value are the same but for quotation reasion is resulted false before. eg: "true" != true, "somevalue" != somevalue
                    istrue='y'
                else
                    break
                fi
            fi
        fi

        if [[ $conditionType == 'OR' ]]
        then
            istrue='n'
            
            # As long as there's value for 1 key is present and it matches the contidion is true.
            # we only need set it to 'n' once when it is empty. because it is OR condition. Hence, if I get 'y' once then the condition is true.
            if [[ -n $foundval ]]
            then
                # only 1 'y' makes the OR condition true.
                istrue='y'
                break                
            fi
            if [[ -n $val && $foundval == $val ]]
            then
                istrue='y'
                foundval=$(echo $foundval | xargs) # remove quote marks from both side
                val=$(echo $val | xargs) # remove quote marks from both side
                if [[ $foundval != $val ]]
                then
                    istrue='n'
                else
                    break
                fi
            fi
        fi
    done

    if [[ $istrue == 'y' ]]
    then
        return 0
    fi

    return 1
}

function checkCondition () {
    local conditionType=$1
    if [[ -z $conditionType ]]
    then
        return 1
    fi
    shift
    local conditions=("$@")
    checkConditionWithDefaultValueFile $conditionType 'na' ${conditions[@]} && return 0 || return 1
}