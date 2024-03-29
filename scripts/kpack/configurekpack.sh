#!/bin/bash

test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

source $HOME/binaries/scripts/select-from-available-options.sh
source $HOME/binaries/scripts/extract-and-take-input.sh
source $HOME/binaries/scripts/color-file.sh



function saveAndApplyFile () {
    
    local filetype=$1 # required. eg: clusterstore, clusterstack, clusterbuilder etc
    local fileprefix=$2 # required. eg: templatename like kpack-clusterstore,kpack-clusterstack etc
    local filesuffix=$3 # required. eg: default, my-cluster-store etc
    local file=$4 # required. eg: /tmp/kpack-clusterstore.tmp
    local namespace=$5 #optional. eg: applicable for builder, store, stack in a perticular namespace.

    if [[ -n $namespace ]]
    then
        namespace="-n $namespace"
    fi

    local issuccessful='n'
    mv $file $HOME/configs/$fileprefix-$filesuffix.yaml && file=$HOME/configs/$fileprefix-$filesuffix.yaml && printf "SAVED\n" && issuccessful='y'
    if [[ $issuccessful == 'y' ]]
    then
        printf "please review $file\n"
        local confirmed=''
        while true; do
            read -p "Would you like to install $filetype: $filesuffix now? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            printf "applying $file..."
            kubectl apply -f $file $namespace && printf "COMPLETED" || printf "FAILED"
            printf "\n"
        elif [[ $confirmed == 'n' ]]
        then
            printf "file is saved ($file). But will not be applied.\n"
        fi
    fi
}


function createKpackClusterStore () {
    
    local configureType=$2 # optional
    if [[ -n $configureType ]]
    then
        configureType="-$configureType"
    fi
    printf "\n\n**** Creating ClusterStore $configureType *****\n\n"

    local clusterstoreTemplateName="kpack-clusterstore$configureType"
    local clusterstoreFile=/tmp/$clusterstoreTemplateName.tmp
    cp $HOME/binaries/templates/$clusterstoreTemplateName.template $clusterstoreFile
    extractVariableAndTakeInput $clusterstoreFile || returnOrexit || return 1

    printf "processing file...\n"
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    sleep 1

    
    if [[ $configureType == '-default' ]]
    then
        KPACK_CLUSTERSTORE_NAME='kpdefault'
    fi
    
    if [[ -n $KPACK_CLUSTERSTORE_NAME ]]
    then
        printf "Checking if $KPACK_CLUSTERSTORE_NAME already exists...."
        local isexistk=$(kubectl describe clusterstore $KPACK_CLUSTERSTORE_NAME)
        if [[ -n $isexistk ]]
        then
            printf "FOUND\n"
            printf "${redcolor}ERROR: Error creating new ClusterStore.\nKpack ClusterStore with name: $KPACK_CLUSTERSTORE_NAME already exists.${normalcolor}\n"
            sleep 2
            returnOrexit || return 1
        else
            printf "NOT FOUND. OK to create new...\n"
        fi
    fi

    printf "saving file..."
    if [[ -z $KPACK_CLUSTERSTORE_NAME ]]
    then
        while [[ -z $KPACK_CLUSTERSTORE_NAME ]]; do
            read -p "input value for kpack clusterstore file: " KPACK_CLUSTERSTORE_NAME
            
            if [[ -z $KPACK_CLUSTERSTORE_NAME ]]
            then
                printf "${redcolor}empty value is not allowed.${normalcolor}\n"                
            fi
        done
    fi
    
    saveAndApplyFile "clusterstore" $clusterstoreTemplateName $KPACK_CLUSTERSTORE_NAME $clusterstoreFile
}

function createKpackClusterStack () {
    
    local configureType=$1 # optional
    if [[ -n $configureType ]]
    then
        configureType="-$configureType"
    fi
    printf "\n\n**** Creating ClusterStack $configureType*****\n\n"

    local clusterstackTemplateName="kpack-clusterstack$configureType"
    local clusterstackFile=/tmp/$clusterstackTemplateName.tmp
    cp $HOME/binaries/templates/$clusterstackTemplateName.template $clusterstackFile
    extractVariableAndTakeInput $clusterstackFile || returnOrexit || return 1

    printf "processing file...\n"
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    sleep 1

    
    if [[ $configureType == '-default' ]]
    then
        KPACK_CLUSTERSTACK_NAME='kpdefaultbase'
    fi

    if [[ -n $KPACK_CLUSTERSTACK_NAME ]]
    then
        printf "Checking if $KPACK_CLUSTERSTACK_NAME already exists...."
        local isexistk=$(kubectl describe clusterstack $KPACK_CLUSTERSTACK_NAME)
        if [[ -n $isexistk ]]
        then
            printf "FOUND\n"
            printf "${redcolor}ERROR: Error creating new ClusterStack.\nKpack ClusterStack with name: $KPACK_CLUSTERSTACK_NAME already exists.${normalcolor}\n"
            sleep 2
            returnOrexit || return 1
        else
            printf "NOT FOUND. OK to create new...\n"
        fi
    fi

    printf "saving file..."
    if [[ -z $KPACK_CLUSTERSTACK_NAME ]]
    then
        while [[ -z $KPACK_CLUSTERSTACK_NAME ]]; do
            read -p "input value for kpack clusterstack file: " KPACK_CLUSTERSTACK_NAME
            
            if [[ -z $KPACK_CLUSTERSTACK_NAME ]]
            then
                printf "${redcolor}empty value is not allowed.${normalcolor}\n"                
            fi
        done
    fi
    
    saveAndApplyFile "clusterstack" $clusterstackTemplateName $KPACK_CLUSTERSTACK_NAME $clusterstackFile
}

function createKpackBuilder () {
    
    local builderType=$1 # Required, Types: clusterbuilder, builder
    local namespace=$2 # Required if builderType=builder
    local configureType=$3 # optional
    if [[ -n $configureType ]]
    then
        configureType="-$configureType"
    fi

    printf "\n\n**** Creating Builder ($builderType$configureType) *****\n\n"
    
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    sleep 1
    export KPACK_CLUSTERBUILDER_SERVICE_ACCOUNT_NAME=$K8S_SERVICE_ACCOUNT_NAME
    
    local builderTemplateName="kpack-$builderType$configureType"
    local builderFile=/tmp/$builderTemplateName.tmp
    local dynamicVariableNameForBuilderName="KPACK_CLUSTERBUILDER_NAME"
    if [[ $builderType == 'builder' ]]
    then
        dynamicVariableNameForBuilderName="KPACK_BUILDER_NAME"
    fi
    cp $HOME/binaries/templates/$builderTemplateName.template $builderFile
    extractVariableAndTakeInput $builderFile || returnOrexit || return 1

    printf "processing file...\n"
    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    sleep 1

    
    if [[ $configureType == '-default' ]]
    then
        KPACK_CLUSTERBUILDER_NAME='kpdefaultclusterbuilder'
        dynamicVariableNameForBuilderName="KPACK_CLUSTERBUILDER_NAME"
    fi
    
    if [[ -n ${!dynamicVariableNameForBuilderName} ]]
    then
        printf "Checking if -n ${!dynamicVariableNameForBuilderName} already exists...."
        local isexistk=$(kubectl describe $buildertype ${!dynamicVariableNameForBuilderName} -n $namespace)
        if [[ -n $isexistk ]]
        then
            printf "FOUND\n"
            printf "${redcolor}ERROR: Error creating new $buildertype.\nKpack $buildertype with name: ${!dynamicVariableNameForBuilderName} already exists.${normalcolor}\n"
            sleep 2
            returnOrexit || return 1
        else
            printf "NOT FOUND. OK to create new...\n"
        fi
    fi

    printf "saving file..."
    local inp=''
    if [[ -z ${!dynamicVariableNameForBuilderName} ]]
    then
        while [[ -z $inp ]]; do
            read -p "input value for $builderType filename: " inp
            
            if [[ -z $inp ]]
            then
                printf "${redcolor}empty value is not allowed.${normalcolor}\n"                
            fi
        done
        saveAndApplyFile $builderType $builderTemplateName $inp $builderFile $namespace
    else
        saveAndApplyFile $builderType $builderTemplateName ${!dynamicVariableNameForBuilderName} $builderFile $namespace
    fi    
}


function configureK8sSecretAndServiceAccount () {


    printf "\n\n${yellowcolor}INFO: kpack utilises K8s Secrets and ServiceAccount (with associated secrets) to connect to private container registries and/or private git repositories."
    printf "\nHence a AerviceAccount, that associates theses secrets (for pvt container registries and pvt git repositories), is required."
    sleep 1
    printf "\nThe ServiceAccount is then referenced in kpack's builder or cluster builder." 
    printf "\nThus, during the build time kpack has the auth information for getting source codes from git repos and push images to container registries.\n"
    sleep 1
    printf "\nNOTE: The kp_default_repository,username and password is for kpack's default images (eg: default builder/cluster builder), whereas these secrets (and service accounts) are for the image registries where kpack will push images to and private git reporsity from where kpack will download source codes from."
    printf "\nIt may seem like that the kp_default_repository,username and password was redundant information, cause it probably was."
    printf "\nYou may provide the same registry credentials."
    printf "${normalcolor}\n\n"
    sleep 1
    

    local configureType=$1

    printf "**** Configure K8s registry secrets, basic secrets (if needed for pvt git repo) and service account for Kpack ******\n"
    

    local namespace=''
    if [[ $configureType == 'default' ]]
    then
        printf "${yellowcolor}Setting namespace to default.${normalcolor}\n"    
        namespace='default'
    else
        printf "\n\n${greencolor}Configuring namespace...\n${yellowcolor}Type the name of namespace where you would like to create secrets and sa for kpack builder. If the namespace does not exist a new namespace will be created using the provided name.${normalcolor}\n"
    fi
    
    while [[ -z $namespace ]]; do
        read -p "Type the name of namespace: " namespace
        if [[ -z $namespace ]]
        then
            printf "Empty value not allowed.\n"
        fi
    done
    if [[ -n $namespace ]]
    then
        printf "Checking namespace $namespace..."
        local isexistk=$(kubectl describe ns $namespace)
        if [[ -z $isexistk ]]
        then
            printf "Namespace: $namespace ... NOT FOUND\n"
            kubectl create ns $namespace
            printf "CREATED\n"
            sleep 2
        else
            printf "FOUND\n"
            sleep 2
        fi
    fi
    export KP_CONFIGURE_NAMESPACE=$namespace

    printf "\n\n${greencolor}Configuring container registry secret for kpack...${normalcolor}\n"
    local dockersecretname=''
    while [[ -z $dockersecretname ]]; do
        read -p "Type the name of existing docker-registry secret in $namespace (type 'new' to create new)? " dockersecretname
        if [[ -z $dockersecretname ]]
        then
            printf "Empty value not allowed.\n"
        elif [[ $dockersecretname != 'new' ]]
        then
            printf "Checking secret: $dockersecretname in $namespace..."
            local isexistk2=$(kubectl describe secret $dockersecretname -n $namespace)
            if [[ -z $isexistk2 ]]
            then
                dockersecretname=''
                printf "${yellowcolor}Secret: $dockersecretname not found in namespace: $namespace ${normalcolor}\n"
            else
                printf "FOUND\n"
            fi
        fi
    done
    if [[ $dockersecretname == 'new' ]]
    then
        printf "Require user input for K8s secret of type docker-registry...\n"
        sleep 1
        local tmpCmdFile=/tmp/kubectl-docker-registry-secret-cmd.tmp
        local cmdTemplate="kubectl create secret docker-registry <DOCKER_REGISTRY_SECRET_NAME> --docker-server <DOCKER_REGISTRY_SERVER> --docker-username <DOCKER_REGISTRY_USERNAME> --docker-password <DOCKER_REGISTRY_PASSWORD> --namespace $namespace"

        echo $cmdTemplate > $tmpCmdFile
        extractVariableAndTakeInput $tmpCmdFile
        cmdTemplate=$(cat $tmpCmdFile)
        rm $tmpCmdFile
        printf "\nCreating new K8s secret of type docker-registry..."
        $(echo $cmdTemplate) && printf "OK" || printf "FAILED"
        printf "\n"
    fi


    printf "\n\n${greencolor}Configuring git repo secret for kpack...${normalcolor}\n"
    local confirmed=''
    while true; do
        read -p "Would you like to create a secret for git registry in namespace: $namespace? [y/n] " yn
        case $yn in
            [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
            [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
            * ) echo "Please answer y or n.";
        esac
    done    
    if [[ $confirmed == 'y' ]]
    then
        local gitsecretname=''
        while [[ -z $gitsecretname ]]; do
            read -p "Type the name of existing secret in $namespace (type 'new' to create new)? " gitsecretname
            if [[ -z $gitsecretname ]]
            then
                printf "Empty value not allowed.\n"
            elif [[ $gitsecretname != 'new' ]]
            then
                printf "Checking secret: $gitsecretname in $namespace..."
                local isexistk3=$(kubectl describe secret $gitsecretname -n $namespace)
                if [[ -z $isexistk3 ]]
                then
                    gitsecretname=''
                    printf "${yellowcolor}Secret: $gitsecretname not found in namespace: $namespace ${normalcolor}\n"
                else
                    printf "FOUND\n"
                fi
            fi
        done
        if [[ $gitsecretname == 'new' ]]
        then
            printf "Require user input k8s secret for git....\n"
            local secretTemplateName="k8s-basic-auth-git-secret"
            local secretFile=/tmp/$secretTemplateName.tmp
            cp $HOME/binaries/templates/$secretTemplateName.template $secretFile
            extractVariableAndTakeInput $secretFile || returnOrexit || return 1

            printf "Creating k8s secret for git...."
            kubectl apply -f $secretFile -n $namespace && printf "CREATED\n" || printf "FAILED\n"
        fi
    fi


    
    printf "\n\n${greencolor}Configuring service account for kpack...${normalcolor}\n"
    
    local saname=''
    if [[ $configureType == 'default' ]]
    then
        saname='kpack-default-sa'
        sed -i '/K8S_SERVICE_ACCOUNT_NAME/d' $HOME/.env
        sleep 1
        printf "\nK8S_SERVICE_ACCOUNT_NAME=$saname\n" >> $HOME/.env
        sleep 1
        printf "Setting sa name: $saname\n"
        printf "Checking sa: $saname in $namespace..."
        local isexistk4=$(kubectl describe sa $saname -n $namespace)
        if [[ -z $isexistk4 ]]
        then
            saname='new'
            printf "NOT FOUND\n"
        else
            printf "FOUND\n"
        fi
    fi
    while [[ -z $saname ]]; do
        read -p "Type the name of existing Service Account in $namespace (type 'new' to create new)? " saname
        if [[ -z $saname ]]
        then
            printf "Empty value not allowed.\n"
        elif [[ $saname != 'new' ]]
        then
            printf "Checking sa: $saname in $namespace..."
            local isexistk5=$(kubectl describe sa $saname -n $namespace)
            if [[ -z $isexistk5 ]]
            then
                saname=''
                printf "${yellowcolor}Secret: $saname not found in namespace: $namespace ${normalcolor}\n"
            fi
        fi
    done
    if [[ $saname == 'new' ]]
    then
        test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
        sleep 1
        printf "User input k8s service account....\n"
        local saTemplateName="k8s-service-account"
        local saFile=/tmp/$saTemplateName.tmp
        cp $HOME/binaries/templates/$saTemplateName.template $saFile
        extractVariableAndTakeInput $saFile || returnOrexit || return 1
        confirmed=''
        while true; do
            read -p "Would you like to add more secrets (eg: git-secret) to this service account? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done  
        if [[ $confirmed == 'y' ]]
        then
            local secretTemplateName="k8s-service-account-secrets"
            local secretFile=/tmp/$secretTemplateName.tmp
            cp $HOME/binaries/templates/$secretTemplateName.template $secretFile
            extractVariableAndTakeInput $secretFile || returnOrexit || return 1
            cat $secretFile >> $saFile
            rm $secretFile
        fi
        printf "Creating k8s service account in namespace: $namespace...."
        kubectl apply -f $saFile -n $namespace && printf "CREATED\n" || printf "FAILED\n"
    fi
    sed -i '/KPACK_CLUSTERBUILDER_SERVICE_ACCOUNT_NAMESPACE/d' $HOME/.env
    sleep 1
    printf "\nKPACK_CLUSTERBUILDER_SERVICE_ACCOUNT_NAMESPACE=$namespace\n" >> $HOME/.env
    sleep 1
    printf "\n\n${greencolor}COMPLETED${normalcolor}\n"
}






function startKpackConfiguration () {

    local configureType=$1 #optional. pass merlin-built-in configure type, eg: 'default'
    

    if [[ $configureType == 'custom' ]]
    then
        configureType=''
    fi

    printf "\n\nprepare..."
    sed -i '/KPACK_CLUSTERSTORE_NAME/d' $HOME/.env
    sed -i '/KPACK_CLUSTERSTACK_NAME/d' $HOME/.env
    sleep 1
    printf ".."
    sed -i '/DOCKER_REGISTRY_SECRET_NAME/d' $HOME/.env
    sed -i '/K8S_BASIC_SECRET_NAME/d' $HOME/.env
    sleep 1
    printf ".."
    sed -i '/K8S_SERVICE_ACCOUNT_NAME/d' $HOME/.env
    sleep 1
    printf ".."
    sed -i '/KPACK_CLUSTERBUILDER_SERVICE_ACCOUNT_NAMESPACE/d' $HOME/.env
    printf "DONE\n"

    local dynamicName=''

    if [[ -n $configureType ]]
    then
        printf "\nconfiguring $configureType kpack\n"
        sleep 2
        configureK8sSecretAndServiceAccount $configureType
        createKpackClusterStack $configureType
        createKpackClusterStore $configureType
        createKpackBuilder "clusterbuilder" "default" $configureType
        dynamicName="KPACK_CLUSTERBUILDER_NAME"
    else
        configureK8sSecretAndServiceAccount

        printf "\nconfiguring kpack based on userinput\n"
        sleep 2
        printf "\n\nconfiguring clusterstack....\n\n"
        sleep 1
        sed -i '/KPACK_CLUSTERSTACK_NAME/d' $HOME/.env
        confirmed=''
        while true; do
            read -p "Would you like configure clusterstack? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            createKpackClusterStack
        fi

        printf "\n\nconfiguring clusterstore....\n\n"
        sleep 1
        sed -i '/KPACK_CLUSTERSTORE_NAME/d' $HOME/.env

        local confirmed=''
        while true; do
            read -p "Would you like configure clusterstore? [y/n] " yn
            case $yn in
                [Yy]* ) printf "you confirmed yes\n"; confirmed='y'; break;;
                [Nn]* ) printf "You confirmed no.\n"; confirmed='n'; break;;
                * ) echo "Please answer y or n.";
            esac
        done
        if [[ $confirmed == 'y' ]]
        then
            createKpackClusterStore
        fi


        printf "\n\nconfiguring kpack builder....\n\n"
        sleep 1
        
        local builderTypeX=''
        printf "what type of builder would you like to create?\n"
        local options=("clusterbuilder" "builder")
        selectFromAvailableOptions ${options[@]}
        local ret=$?
        if [[ $ret == 255 ]]
        then
            printf "${redcolor}No selection were made.${normalcolor}\n"
        else
            # selected option
            builderTypeX=${options[$ret]}
        fi
        if [[ -n $builderTypeX ]]
        then
            dynamicName="KPACK_CLUSTERBUILDER_NAME"
            if [[ $builderTypeX == 'builder' ]]
            then
                dynamicName="KPACK_BUILDER_NAME"
            fi
            sed -i '/'$dynamicName'/d' $HOME/.env
            createKpackBuilder $builderTypeX $KP_CONFIGURE_NAMESPACE
        fi
    fi   



    printf "\n\ncleanup..."
    sed -i '/KPACK_CLUSTERSTORE_NAME/d' $HOME/.env
    sleep 1
    printf ".."
    sed -i '/KPACK_CLUSTERSTACK_NAME/d' $HOME/.env
    sleep 1
    printf ".."
    if [[ -n $dynamicName ]]
    then
        sed -i '/'$dynamicName'/d' $HOME/.env
        sleep 1
    fi
    printf ".."
    sed -i '/DOCKER_REGISTRY_SECRET_NAME/d' $HOME/.env
    sleep 1
    printf ".."
    sed -i '/K8S_BASIC_SECRET_NAME/d' $HOME/.env
    sleep 1
    printf ".."
    sed -i '/K8S_SERVICE_ACCOUNT_NAME/d' $HOME/.env
    sleep 1
    printf ".."
    sed -i '/KPACK_CLUSTERBUILDER_SERVICE_ACCOUNT_NAMESPACE/d' $HOME/.env
    printf "DONE\n"
}


function startConfigureKpack () {

    printf "${yellowcolor}Select what type of kpack configuration you would like to do?${normalcolor}\n"
    local options=("default" "custom")
    selectFromAvailableOptions ${options[@]}
    local ret=$?
    if [[ $ret == 255 ]]
    then
        printf "${redcolor}No selection were made.${normalcolor}\n"
    else
        startKpackConfiguration ${options[$ret]}
        
    fi
}