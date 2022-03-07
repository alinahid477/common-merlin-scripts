#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/contains-element.sh
source $HOME/binaries/scripts/select-from-available-options.sh
source $HOME/binaries/scripts/keyvaluefile-functions.sh

function customConditionParser () {
    # eg: customConditionARR=CLUSTER_PLAN=dev&INFRASTRUCTURE=vsphere;defaultvalue=1
    # eg: customConditionARR=CLUSTER_PLAN=dev&INFRASTRUCTURE=vsphere;defaultkey=MACHINE_COUNT
    local customConditionSTR=$1 # required. 
    local defaultValuesFile=$2 # optional.
    if [[ -z $customConditionSTR || $customConditionSTR == null ]]
    then
        return 1
    fi
    
    local conditionAndValuePair=(${customConditionSTR//;/ })
    local conditionOnlySTR=${conditionAndValuePair[0]}
    
    local conditionsArr=(${conditionOnlySTR//&/ })

    #check if condition is met
    for condition in ${conditionsArr[@]}; do
        local kvpair=(${condition//=/ })
        local k=${kvpair[0]}
        local v=${kvpair[1]}
        local foundval=$(findValueForKey $k $defaultValuesFile)
        if [[ -n $v ]]
        then
            local v1=$(echo $v | xargs)
            local foundval1=$(echo $foundval | xargs)
            if [[ $v != $foundval && $v1 != $foundval1 ]]
            then
                return 1
            fi
        else
            # if value is not present, this means as the condition is: "as long as there's a value" (doesnt matter what value it is) the condition is true.
            # This sort of mimics ISSET functionality
            if [[ -z $foundval ]]
            then
                # no value found so condition is false.
                return 1
            fi
        fi
    done
    
    local valueSTR=${conditionAndValuePair[1]}
    local kvpair=(${valueSTR//=/ })
    if [[ ${kvpair[0]} == 'defaultvalue' ]]
    then
        printf ${kvpair[1]}
    else
        if [[ ${kvpair[0]} == 'defaultkey' ]]
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



function extractVariableAndTakeInput () {
    local templateFilesDIR=$(echo "$HOME/binaries/templates" | xargs)
    local promptsForVariablesJSON='prompts-for-variables.json'

    variableFile=$1
    defaultValuesFile=$2

    if [[ -z $variableFile ]]
    then
        printf "\nERROR: Must pass base variable file as parameter\n"
        return 1
    fi
    
    printf "extracting variables for user input....\n"
    # extract variable from file (variable format is: <NAME-OF-THE-VARIABLE>)
    local allVariables=($(grep -o '<[A-Za-z0-9_\-]*>' $variableFile))
    local uniqueVariables=()

    # populate keys with unique values only (in the file there may be multiple occurances of same variables)
    local i=0
    while [[ $i -lt ${#allVariables[*]} ]] ; do
        containsElement "${allVariables[$i]}" "${uniqueVariables[@]}"
        ret=$?
        if [[ $ret == 1 ]]
        then
            uniqueVariables+=("${allVariables[$i]}")
        fi
        ((i=$i+1))
    done


    local isinputneeded='n'

    # iterate over each variable name that may need user input (if not exist as environment variable)
    for variableNameRaw in "${uniqueVariables[@]}"; do
        printf "\n\n"
        # modifying the extracted variable name to valid variable name format 
        # eg: extracted variable name was: <NAME-OF-THE-VARIABLE>. So
        # 1. Modify to remove '<' and '>'
        # 2. Modify to replace '-' with '_'
        # so, <NAME-OF-THE-VARIABLE> is modified to NAME_OF_THE_VARIABLE
        inputvar=$(echo "${variableNameRaw}" | sed 's/[<>]//g' | sed 's/[-]/_/g')
        
        local skip_prompt=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .skip_prompt' $templateFilesDIR/$promptsForVariablesJSON)
        local optional=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .optional' $templateFilesDIR/$promptsForVariablesJSON)

        if [[ $skip_prompt == null ]]
        then
            skip_prompt=''
        fi
        if [[ $optional == null ]]
        then
            optional=''
        fi

        local defaultvaluekey=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .defaultvaluekey' $templateFilesDIR/$promptsForVariablesJSON)
        local defaultvalue=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .defaultvalue' $templateFilesDIR/$promptsForVariablesJSON)
        
        
        # Custom condition logic: this logic was added later. Mostlikely this is how default values with AND or OR or ISSET or NOTISSET conditions will be determined
        local conditionalvalue=''
        readarray -t conditionalvalue < <(jq -r '.[] | select(.name == "'$variableNameRaw'") | .conditionalvalue' $templateFilesDIR/$promptsForVariablesJSON)
        
        local ret=255
        local isAndConditionMet=true
        if [[ -n $conditionalvalue && $conditionalvalue != null && ${#conditionalvalue[@]} -gt 0 ]]
        then
            local conditionsLookupFile=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .conditions_lookup_file' $templateFilesDIR/$promptsForVariablesJSON)
            local returnedValue=''
            # when conditions mentioned in the 'conditionalvalue' are met this will overwrite default value
            if [[ $conditionsLookupFile == 'this' ]]
            then
                returnedValue=$(conditionalValueParserArray $variableFile ${conditionalvalue[@]})
            else
                if [[ $conditionsLookupFile == 'default' ]]
                then
                    returnedValue=$(conditionalValueParserArray $defaultValuesFile ${conditionalvalue[@]})
                fi
            fi
            
            if [[ -n $returnedValue ]]
            then
                defaultvalue=$returnedValue
            else
                isAndConditionMet=false
            fi
        else
            # this is the old way of honoring defaultvalue or value for defaultkey when condition is met
            # goind forward the above should be the way to do it.
            local andconditions=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .andconditions' $templateFilesDIR/$promptsForVariablesJSON)
            if [[ -n $andconditions && $andconditions != null ]]
            then
                # read it as an array because the funtion 'checkConditionWithDefaultValueFile' expects array.
                andconditions=($(echo "$andconditions" | jq -rc '.[]'))
                local andconditionsLookupFile=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .conditions_lookup_file' $templateFilesDIR/$promptsForVariablesJSON)
                
                # andconditions will only exist in combination with EITHER optional=true OR skip_prompt=true
                if [[ $andconditionsLookupFile == 'this' ]]
                then
                    # this means the andconditions is based on an input that I have provided previously (during the generation for this file)
                    # and it exists in this file (aka $variableFile)
                    checkConditionWithDefaultValueFile "AND" $variableFile ${andconditions[@]} 
                else
                    if [[ $andconditionsLookupFile == 'default' ]]
                    then 
                        # this means the andconditions is based on an the default value file eg: management-cluster-config.yaml
                        checkConditionWithDefaultValueFile "AND" $defaultValuesFile ${andconditions[@]}
                    else
                        checkCondition # this will return 1 becuase it will fail the null check         
                    fi
                fi
                ret=$? # 0 means checkCondition was true else 1 meaning check condition is false
                if [[ $ret == 1 ]]
                then
                    # condition is false.
                    isAndConditionMet=false
                fi            
            fi
        fi

        

        ## LOGIC ##
        # delete the variable from output file if
        # andcondition is NOT met and optional=true || skip_prompt=true
        # This is only reason optional=true exists.--> Basically this means that if a variable is optional and the condition to it is not met (eg: AZURE_PRIVATE_IP) then remove it from the file.
        # skip_prompt=true has another purpose--->See below, 
        #     which is, when skip_prompt=true and default value exists (either defaultvalue or extracted from defaultvaluekey) and if there's andconditions which is also met then do not ask for input.
        #          
        if [[ (($skip_prompt == true || $optional == true)) && $isAndConditionMet == false ]]
        then
            sed -i '/'$inputvar'/d' $variableFile
            continue
        fi
        
        # prompt user for input if
        # andcondition is met and optional=true

        # write the defaultvalue (specified or extracted) in the ouput file if
        # andcondition is met and skip_prompt=true

        # andcondition being true and it being empty carries same meaning because
        # if andconditions is true then it will follow the rule for skip_prompt or optional
        # if andconditions is empty it will be same as above
        
        
        



        # value found in either defaultValuesFile (eg: mgmtclusterconfig.yaml) or environment variable 
        if [[ -n $defaultvaluekey && $defaultvaluekey != null ]]
        then
            # first get the value against the key mentioned
            local foundval=$(findValueForKey $defaultvaluekey $defaultValuesFile)

            # value found will take precedence over defaultValue mentioned in the pompts-for-variable.json
            if [[ -n $foundval && $foundval != null ]]
            then
                defaultvalue=$foundval
            fi
        fi


        
        # read hint from pompts variable file and display it
        hint=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .hint' $templateFilesDIR/$promptsForVariablesJSON)
        if [[ -n $hint && $hint != null ]]
        then
            printf "Variable: $inputvar\n${bluecolor}Hint: $hint ${normalcolor}\n"
        fi        
        
        # rule of skip_prompt=true --> if there is a defaultvalue exist do not propmt user
        # if no defaultvalue exist then prompt user. skip_prompt does not mean anything here.
        if [[ $skip_prompt == true && -n $defaultvalue && $defaultvalue != null ]]
        then
            printf "${yellowcolor}Skipping user input. default value: $inputvar=$defaultvalue${normalcolor}\n"
            local useSpecialReplace=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .use_special_replace' $templateFilesDIR/$promptsForVariablesJSON)
            # printf "\nDBG: $useSpecialReplace\n"
            if [[ -n $useSpecialReplace && $useSpecialReplace == true ]]
            then
                awk -v old=${variableNameRaw} -v new="$defaultvalue" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $variableFile > $variableFile.tmp && mv $variableFile.tmp $variableFile
                sleep 1
            else
                sed -i 's|'${variableNameRaw}'|'$defaultvalue'|g' $variableFile
            fi
            
            continue
        fi

        
        unset inp
        # dynamic variable-->eg: variable name (NAME_OF_THE_VARIABLE) in a variable ('inputvar')
        # the way to access the value dynamic variable is: ${!inputvar}

        # if input variable does not exist as environment variable (meaning if the value is empty or unset that means variable does not exists)
        # Hence, need to prompt user for input and take userinput.
        if [[ -z ${!inputvar} ]]; then
            # when does not exist prompt user to input value
            isinputneeded='y'
            
            local optionsJson=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .options' $templateFilesDIR/$promptsForVariablesJSON)

            # when defaultvalue exists prompt user the default value and give user option to 'press enter' to accept it.
            # then prompt user for input against the variable.
            # if no defaultvalue exist then regardless of optional=true or false prompt user for input against the variable.
            # So I only need to check the below condition to say empty is allowed
            local isEmptyAllowed=false
            if [[ -n $defaultvalue && $defaultvalue != null ]]
            then
                if [[ -z $optionsJson || $optionsJson == null ]]
                then
                    printf "${greencolor}Press enter to accept Default: $defaultvalue${normalcolor}\n"
                fi
                isEmptyAllowed=true
            fi
            
            if [[ -n $optionsJson && $optionsJson != null ]]
            then
                # this means user input need to come from a list

                local selectedOption=''
                # read it as array so I can perform containsElement for valid value from user input.
                readarray -t options < <(echo $optionsJson | jq -rc '.[]')
                if [[ -n $defaultvalue && $defaultvalue != null ]]
                then
                    selectFromAvailableOptionsWithDefault $defaultvalue ${options[@]}
                else
                    selectFromAvailableOptions ${options[@]}
                fi
                
                ret=$?
                if [[ $ret == 255 ]]
                then
                    printf "${bluecolor}No selection were made. Remove the entry${normalcolor}\n"
                    sed -i '/'$inputvar'/d' $variableFile
                else
                    # selected option
                    inp=${options[$ret]}
                fi
            fi

            
            while [[ -z $inp ]]; do
                read -p "input value for $inputvar: " inp
                if [[ -z $inp ]]
                then
                    if [[ $isEmptyAllowed == true && -n $defaultvalue && $defaultvalue != null ]]
                    then
                        # this means the input-for-values.json has optional=true and there exist default value (either defaultvalue: "some value" OR defaultvaluekey: "somekey")
                        inp=$defaultvalue    
                    else
                        printf "${redcolor}empty value is not allowed.${normalcolor}\n"
                    fi                
                fi
            done
            if [[ $isEmptyAllowed == true && $inp == $defaultvalue ]]
            then
                # this means user pressed enter to accept default value
                printf "${greencolor}Accepted default value: $inp${normalcolor}\n"
            else
                local inp1=$(echo $inp | xargs)
                local defaultvalue1=$(echo $defaultvalue | xargs)
                if [[ $isEmptyAllowed == true && $inp1 == $defaultvalue1 ]]
                then
                    printf "${greencolor}Accepted default value: $inp${normalcolor}\n"
                fi
            fi
            local useSpecialReplace=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .use_special_replace' $templateFilesDIR/$promptsForVariablesJSON)
            # printf "\nDBG: $useSpecialReplace\n"
            if [[ -n $useSpecialReplace && $useSpecialReplace == true ]]
            then
                awk -v old=${variableNameRaw} -v new="$inp" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' $variableFile > $variableFile.tmp && mv $variableFile.tmp $variableFile
                sleep 1
            else
                sed -i 's|'${variableNameRaw}'|'$inp'|g' $variableFile
            fi
            
            # read this property to see if this variable should be recorded in .env file for usage in developer workspace (eg: git-ops-secret)
            isRecordAsEnvVar=$(jq -r '.[] | select(.name == "'$variableNameRaw'") | .isRecordAsEnvVar' $templateFilesDIR/$promptsForVariablesJSON)
            # add to .env for later use if instructed in the prompt file (eg: during developer namespace creation)            
            if [[ -n $isRecordAsEnvVar && $isRecordAsEnvVar == true ]]
            then
                printf "\n" >> $HOME/.env
                printf "$inputvar=${inp}" >> $HOME/.env
                printf "\n" >> $HOME/.env
            fi
        else
            # when exists as environment variable already, no need to prompt user for input. Just replace in the file.
            inp=${!inputvar} # the value of the environment variable (here accessed as dynamic variable)
            printf "environment variable found: $inputvar=$inp\n"
            sed -i 's|<'$inputvar'>|'$inp'|g' $variableFile
        fi
    done

    if [[ $isinputneeded == 'n' ]]
    then
        printf "\nAll needed values found in environment variable. No user input needed.\n"
    fi


    return 0
}