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

function checkCondition () { # returns 0 if condition is met. Otherwise returns 1.

    local conditionType=$1  # (Required) possible values are either 'AND' or 'OR'
    local conditionsJson=$2 # (Required) comma separated json string
    local keyValueFile=$3   # (Optional) filepath of the keyvalue file (single or multiple lines containing format 'key: value'. eg: tkgm clusterconfig file)


    if [[ -z $conditionType || -z $conditionsJson || $conditionsJson == null ]] # sincce conditionsJson is extracted from json it can be null. 
    then
        return 1
    fi


    readarray -t conditions < <(echo $conditionsJson | jq -rc '.[]')
    

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
            # When it is only [ "SOME_KEY" ] the $val will be empty, which means, the condition is "if there exists a value for "SOME_KEY" and I dont care what value."
            # BUT WHENE it is [ "SOME_KEY=SOME_VAL" ] I care about the key and matching the value too, eg: must be $foundval=SOME_VAL
            if [[ -z $foundval || (( -n $val && $foundval != $val )) ]]
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
            if [[ -n $foundval && (( -n $val && $foundval == $val )) ]]
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