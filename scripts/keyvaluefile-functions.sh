#!/bin/bash
export $(cat $HOME/.env | xargs)

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


# this is the latest adition that makes checkConditionWithDefaultValueFile or checkCondition functions obsolete. 
# however, keeping checkConditionWithDefaultValueFile or checkCondition functions for backward compatibility.
# this function is capable of tacking ==, !=, isset (MY_KEY) and notisset (!MY_KEY) conditions
function conditionalValueParser () { # takes 1 required and 1 optional params and returns the value of defautvalue or defaultkey's value

    # eg: customConditionSTR: CLUSTER_PLAN==dev&&INFRASTRUCTURE==vsphere;defaultvalue=1 --> CLUSTER_PLAN equal dev && INFRASTRUCTURE==vsphere
    # eg: customConditionSTR: CLUSTER_PLAN!=dev&&INFRASTRUCTURE==vsphere;defaultkey=MACHINE_COUNT --> CLUSTER_PLAN not equal dev && INFRASTRUCTURE==vsphere
    # eg: customConditionSTR: CLUSTER_PLAN&&INFRASTRUCTURE==vsphere;defaultkey=MACHINE_COUNT --> CLUSTER_PLAN isset && INFRASTRUCTURE==vsphere
    # eg: customConditionSTR: !CLUSTER_PLAN&&INFRASTRUCTURE==vsphere;defaultvalue=bla --> CLUSTER_PLAN isset not set && INFRASTRUCTURE==vsphere
    # eg: customConditionSTR: !CLUSTER_PLAN;defaultvalue=bla --> CLUSTER_PLAN isset not set
    local customConditionSTR=$1 # required. 
    local defaultValuesFile=$2 # optional.
    if [[ -z $customConditionSTR || $customConditionSTR == null ]]
    then
        return 1
    fi
    
    local conditionAndValuePair=(${customConditionSTR//;/ })
    local conditionOnlySTR=${conditionAndValuePair[0]}
    
    local conditionsArr=($conditionOnlySTR)
    local conditionType='AND'
    if [[ $conditionOnlySTR == *"&&"* ]]
    then
        conditionsArr=(${conditionOnlySTR//'&&'/ })
    else 
        if [[ $conditionOnlySTR == *"||"* ]]
        then
            conditionType='OR'
            conditionsArr=(${conditionOnlySTR//'||'/ })
        fi
    fi
    
    local isConditionMet=''
    #check if condition is met
    for condition in ${conditionsArr[@]}; do
        local logic='=='
        local kvpair=(${condition//'=='/ })
        if [[ ${#kvpair[@]} -lt 2 ]]
        then
            logic='!='
            kvpair=(${condition//'!='/ })
        fi
        local k=${kvpair[0]}
        local v=${kvpair[1]}
        local ifisset=true
        if [[ $k =~ ^!.* ]]
        then
            ifisset=false
            k=$(echo $k | sed 's/!//')
        fi
        local foundval=$(findValueForKey $k $defaultValuesFile)
        
        if [[ $conditionType == 'AND' ]]
        then
            isConditionMet=true
            if [[ -n $v ]]
            then
                # if there's a value given to condition then there must be foundval present.
                # so if foundval is not present then it is false regardless of logic and condition
                if [[ -z $foundval ]]
                then
                    isConditionMet=false
                    return 1
                fi
                if [[ $logic == '==' ]]
                then
                    if [[ $v != $foundval ]]
                    then
                        isConditionMet=false
                        return 1
                    else
                        local v1=$(echo $v | xargs)
                        local foundval1=$(echo $foundval | xargs)
                        if [[ $v1 != $foundval1 ]]
                        then
                            isConditionMet=false
                            return 1
                        fi
                    fi
                else
                    if [[ $logic == '!=' ]]
                    then
                    if [[ $v == $foundval ]]
                        then
                            isConditionMet=false
                            return 1
                        else
                            local v1=$(echo $v | xargs)
                            local foundval1=$(echo $foundval | xargs)
                            if [[ $v1 == $foundval1 ]]
                            then
                                isConditionMet=false
                                return 1
                            fi
                        fi  
                    fi
                fi
            else
                # if value is not present, this means as the condition is: "as long as there's a value" (doesnt matter what value it is) the condition is true.
                # This sort of mimics ISSET functionality
                if [[ -z $foundval && $ifisset == true ]]
                then
                    # no value found but I want isset, so confition did not meet
                    isConditionMet=false
                    return 1
                fi

                # if value is NOT present (!MY_KEY), this means as the condition is: "as long as there ISNT a value" the condition is true.
                # This sort of mimics ISSET functionality
                if [[ -n $foundval && $ifisset == false ]]
                then
                    # value is present but I want NOT isset, so condition did not meet
                    isConditionMet=false
                    return 1
                fi
            fi
        else
            if [[ $conditionType == 'OR' ]]
            then
                isConditionMet=false
                if [[ -n $v ]]
                then
                    # if there's a value given to condition then there must be foundval present.
                    # so if foundval is not present then it is false regardless of logic and condition
                    if [[ -z $foundval ]]
                    then
                        isConditionMet=false
                        break
                    fi
                    if [[ $logic == '==' ]]
                    then
                        if [[ $v == $foundval ]]
                        then
                            isConditionMet=true
                            break
                        else
                            local v1=$(echo $v | xargs)
                            local foundval1=$(echo $foundval | xargs)
                            if [[ $v1 == $foundval1 ]]
                            then
                                isConditionMet=true
                                break
                            fi
                        fi
                    else
                        if [[ $logic == '!=' ]]
                        then
                        if [[ $v != $foundval ]]
                            then
                                isConditionMet=true
                                break
                            else
                                local v1=$(echo $v | xargs)
                                local foundval1=$(echo $foundval | xargs)
                                if [[ $v1 != $foundval1 ]]
                                then
                                    isConditionMet=true
                                    break
                                fi
                            fi  
                        fi
                    fi
                else

                    # if value is not present, this means as the condition is: "as long as there's a value" (doesnt matter what value it is) the condition is true.
                    # This sort of mimics ISSET functionality
                    if [[ -z $foundval && $ifisset == false ]]
                    then
                        # no value found but I want isset, so confition did not meet
                        isConditionMet=true
                        break
                    fi

                    # if value is NOT present (!MY_KEY), this means as the condition is: "as long as there ISNT a value" the condition is true.
                    # This sort of mimics ISSET functionality
                    if [[ -n $foundval && $ifisset == true ]]
                    then
                        # value is present but I want NOT isset, so condition did not meet
                        isConditionMet=true
                        break
                    fi
                fi
            fi
        fi     
        
    done
    
    if [[ -z $isConditionMet || $isConditionMet == false ]]
    then
        return 1
    fi


    local valueOnlySTR=${conditionAndValuePair[1]}
    local kvpair=(${valueOnlySTR//=/ })
    
    if [[ ${kvpair[0]} == 'defaultvalue' ]]
    then
        printf ${kvpair[1]}
    else
        if [[ ${kvpair[0]} == 'defaultkey' || ${kvpair[0]} == 'defaultvaluekey' ]]
        then
            local foundval=$(findValueForKey ${kvpair[1]} $defaultValuesFile)
            if [[ -n $foundval ]]
            then
                printf $foundval
            else
                return 1
            fi
        else
            return 1
        fi
    fi
    
    return 0
}


# this functin takes the array form json parses 1 contidion at a time (in for loop)
# as soon as it finds a result it ignores parsing the rest of the conditions
# because the logic/assumtion is there is only 1 true condition if it exists as there can be only value to be returned
# eg: "conditionalvalue": ["CLUSTER_PLAN==dev;defaultvalue=1", "CLUSTER_PLAN==prod&&INFRA==vsphere;defaultvalue=3", "CLUSTER_PLAN&&INFRA==aws;defaultkey=MACHINE_COUNT"]
function conditionalValueParserArray () {
    local defaultValuesFile=$1 # required. pass 'na' if there's no defaultValuesfile, otherwise pass the full path of the file.
    shift
    local customConditionsARR=("$@") # required. 
    
    if [[ -z $customConditionsARR || $customConditionsARR == null || ${#customConditionsARR[@]} -lt 1 ]]
    then
        return 1
    fi

    if [[ $defaultValuesFile == 'na' ]]
    then
        defaultValuesFile=''
    fi

    for customCondition in ${customConditionsARR[@]}; do
        local returnedValue=$(conditionalValueParser $customCondition $defaultValuesFile)
        if [[ -n $returnedValue ]]
        then
            printf $returnedValue
            return 0
        fi
    done

    return 1
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