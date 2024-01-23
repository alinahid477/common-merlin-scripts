#!/bin/bash

installTanzuCLIPlugins () {
    export TANZU_CLI_CEIP_OPT_IN_PROMPT_ANSWER=yes
    printf "\nInstalling Tanzu Cli Plugins...\nAccepting EULA...\n"
    tanzu config eula accept
    printf "installing tanzu plugins: package, secret, apps, accelerator...\n"
    tanzu plugin install package
    tanzu plugin install secret --target k8s
    tanzu plugin install apps --target k8s
    tanzu plugin install accelerator --target k8s
    printf "\n\nTanzu Plugin Install....COMPLETE.\n"
}

installTanzuCLI () {

    local tanzuclitarfiledir=$HOME/binaries
    if [[ -n $1 ]]
    then
        tanzuclitarfiledir=$1
    fi

    local isTanzuCLIInstalled=$(which tanzu)
    if [[ -n $isTanzuCLIInstalled ]]
    then
        printf "\n\nTanzu CLI already installed. No need to install again.\n"
        local iscorecli=$(ls $HOME/tanzu/ | grep "v[0-9\.]*$")
        if [[ -n $iscorecli ]]
        then
            local totaltanzuplugins=$(tanzu plugin list -o json | jq length)
            if [[ -z $totaltanzuplugins || $totaltanzuplugins < 4 ]]
            then
                installTanzuCLIPlugins
            fi
            tanzu plugin list
        else
            tanzu plugin list --local $HOME/tanzu/
        fi

        
        return 0
    fi

    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true


    
    printf "\nChecking Tanzu CLI binary..."
    sleep 1
    local isinflatedTZ='n'
    local DIR="$HOME/tanzu"
    if [ -d "$DIR" ]
    then
        if [ "$(ls -A $DIR)" ]
        then
            isinflatedTZ='y'
            printf "\nFound tanzu cli is already inflated in $DIR.\nSkipping further checks.\n"
        fi
    fi
    sleep 1
    local tanzuclibinary=''
    if [[ $isinflatedTZ == 'n' ]]
    then
        printf "\nFinding tanzu cli binaries...."
        # default look for: tanzu tap cli
        local tarfilenamingpattern="tanzu-framework-linux-amd64*"
        tanzuclibinary=$(ls $tanzuclitarfiledir/$tarfilenamingpattern)
        if [[ -z $tanzuclibinary ]]
        then
            # fallback look for: tanzu ent
            tarfilenamingpattern="tanzu-cli-linux-*.tar.*"
            tanzuclibinary=$(ls $tanzuclitarfiledir/$tarfilenamingpattern)
        fi
        if [[ -z $tanzuclibinary ]]
        then
            # fallback look for: tanzu tce
            tarfilenamingpattern="tce-*.tar.*"
            tanzuclibinary=$(ls $tanzuclitarfiledir/$tarfilenamingpattern)
        fi
        if [[ -z $tanzuclibinary ]]
        then
            printf "\nERROR: tanzu CLI is a required binary for installation.\nYou must place this binary under binaries directory.\n"
            return 1
        else
            local numberoftarfound=$(find $tanzuclitarfiledir/$tarfilenamingpattern -type f -printf "." | wc -c)
            if [[ $numberoftarfound -gt 1 ]]
            then
                printf "\nERROR: More than 1 tanzu-cli tar file found in the binaries directory.\nOnly 1 is allowed.\n"
                return 1
            else
                printf "found: $tanzuclibinary\n"
            fi
        fi
    fi
    sleep 1

    if [[ $isinflatedTZ == 'n' && -n $tanzuclibinary ]]
    then
        # at this point we have identified that it has not been untared before. AND we have 1 tar file of tanzu cli distribution
        # let's untar it.
        printf "\nInflating Tanzu CLI in $DIR...\n"
        sleep 1
        if [ ! -d "$DIR" ]
        then
            printf "Creating new $DIR..."
            mkdir -p $HOME/tanzu && printf "OK" || printf "FAILED"
            printf "\n"
        else
            if [[ -z $SILENTMODE || $SILENTMODE != 'YES' ]]
            then
                printf "$DIR already exits...\n"
                while true; do
                    read -p "Confirm to untar in $DIR [y/n]: " yn
                    case $yn in
                        [Yy]* ) doinflate="y"; printf "\nyou confirmed yes\n"; break;;
                        [Nn]* ) doinflate="n";printf "\nYou said no.\n"; break;;
                        * ) printf "${redcolor}Please answer y or n.${normalcolor}\n";;
                    esac
                done
            fi
        fi
        if [[ $doinflate == 'n' ]]
        then
            # user is saying no inflate here. so nothing to do here.
            return 2;
        fi
        if [ ! -d "$DIR" ]
        then
            printf "\nERROR: $DIR does not exist. Exiting...\n"
            return 1
        fi
        printf "Extracting $tanzuclibinary in $DIR....\n"
        tar -xvf $tanzuclibinary -C $HOME/tanzu/ || return 1
        printf "$tanzuclibinary extracted in $DIR......COMPLETED.\n\n"
    fi
    sleep 1
    cd ~
    local isexisttanzu=$(which tanzu)
    if [[ -d $DIR && -z $isexisttanzu ]]
    then
        # default check tce
        local extracteddirname=$(ls $HOME/tanzu/ | grep "v[0-9\.]*$")
        if [[ -n $extracteddirname ]]
        then
            # this mean we are dealing with tce tanzu cli.
            printf "\nDetermining tanzu cli in $extracteddirname...\n"
            
            cd $HOME/tanzu/$extracteddirname || return 1

            # UPDATED: 24/08/2023
            # TANZU CLI has changed to different one. TANZU CORE CLI.
            local tanzucliinstallbinaryname=$(ls | head -1 | grep tanzu-cli)
            if [[ -f $tanzucliinstallbinaryname ]]
            then
                local currentUser=$(whoami)
                printf "installing $tanzucliinstallbinaryname as $currentUser...\n\n"
                if [[ $currentUser == "root" ]]
                then
                    install $tanzucliinstallbinaryname /usr/local/bin/tanzu || return 1
                    chmod +x /usr/local/bin/tanzu || return 1
                    printf "installed /usr/local/bin/tanzu.\n"
                else
                    if [[ ":$PATH:" == *":$HOME/.local/bin:"* && -d $HOME/.local/bin ]]
                    then
                        install $tanzucliinstallbinaryname $HOME/.local/bin/tanzu || return 1
                        chmod +x $HOME/.local/bin/tanzu || return 1
                        printf "installed $HOME/.local/bin/tanzu.\n"
                    else
                        printf "\nERROR: $currentUser does not have $HOME/.local/bin in the PATH or $HOME/.local/bin directory does not exist.\n"
                        return 1
                    fi
                fi
                installTanzuCLIPlugins
                printf "Tanzu Install...COMPLETE.\n"
            else
                # TCE Tanzu CLI install
                # This means previously not installed.
                # Linking tanzu binary as part of the install.sh script shipped in the zip file.
                printf "installing (tce) tanzu...\n"
                export ALLOW_INSTALL_AS_ROOT=true
                sleep 1
                chmod +x install.sh
                ./install.sh
                sleep 1
                unset ALLOW_INSTALL_AS_ROOT
                printf "\nTanzu CLI installation...COMPLETE.\n\n"
            fi            
        else
            # fallback to tanzu cli TAP or ENT. bellow is same for both of them.
            local tanzuframworkVersion=$(ls $HOME/tanzu/cli/core/ | grep "^v[0-9\.]*$")
            if [[ -z $tanzuframworkVersion ]]
            then
                printf "\nERROR: could not found version dir in the $HOME/tanzu/cli/core for tanzu cli.\n"
                return 1;
            fi
            printf "\nLinking tanzu cli ($tanzuframworkVersion)...\n"
            cd $HOME/tanzu || return 1
            
            # Link the tanzu binary. Cause that's needs to happen regardless of whether it was previously installed or not.
            if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
                # if docker container is running as non root user
                if [ ! -d "$HOME/.local/bin" ]; then
                    mkdir -p "$HOME/.local/bin"
                fi
                install cli/core/$tanzuframworkVersion/tanzu-core-linux_amd64 $HOME/.local/bin/tanzu || return 1
                chmod +x $HOME/.local/bin/tanzu || return 1
            else
                # if docker container is root user
                echo "Installing tanzu to /usr/local/bin which is write protected"
                echo "If you'd prefer to install tanzu without sudo permissions, add \$HOME/.local/bin to your \$PATH and rerun the installer"
                install cli/core/$tanzuframworkVersion/tanzu-core-linux_amd64 /usr/local/bin/tanzu || return 1
                chmod +x /usr/local/bin/tanzu || return 1
            fi
                        
            if [[ ! -d $HOME/.local/share/tanzu-cli/package ]]
            then
                # UPDATE: 24/05/2023
                # The below commented section is not required anymore as there's only 1 tanzu CLI now (product has consolidate tap tanzu cli and ent tanzu cli into 1 disti).

                # This means tanzu cli plugins were not installed and we need plugins. Lets install it.
                # if [[ -f cli/manifest.yaml ]]
                # then
                #     # TAP Tanzu CLI install
                #     # This means the previously installed distribution was TAP tanzu cli
                #     # the manifest file exist in the case of TAP distribution of TANZU CLI
                #     printf "installing tanzu plugin from local..."
                #     if [[ -n $SILENTMODE && $SILENTMODE == 'YES' ]]
                #     then
                #         tanzu plugin install secret --local ./cli && sleep 1
                #         tanzu plugin install package --local ./cli && sleep 1
                #         tanzu plugin install external-secrets --local ./cli && sleep 1
                #     else
                #         tanzu plugin install --local cli all || returnOrexit || return 1
                #     fi                    
                #     tanzu plugin install apps --local ./cli && sleep 1
                #     printf "\nCOMPLETE.\n"
                # else
                #     # ENT Tanzu CLI install
                #     # This means the previously installed distribution was tanzu cli ENT
                #     printf "Removing existing plugins from any previous CLI installations..."
                #     tanzu plugin clean || returnOrexit
                #     printf "COMPLETE.\n"
                #     printf "Installing all the plugins for this release..."
                #     tanzu plugin sync || returnOrexit
                #     printf "COMPLETE.\n"
                # fi
                printf "installing tanzu plugin from local..."
                # if [[ -n $SILENTMODE && $SILENTMODE == 'YES' ]]
                # then
                #     tanzu plugin install secret --local ./cli && sleep 1
                #     tanzu plugin install package --local ./cli && sleep 1
                #     tanzu plugin install external-secrets --local ./cli && sleep 1
                # else
                #    tanzu plugin install --local cli all || returnOrexit || return 1
                # fi
                tanzu plugin install --local cli all || return 1
                tanzu plugin install apps --local ./cli && sleep 1
                printf "\nTanzu CLI installation...COMPLETE.\n\n"
            fi
        fi
        
        sleep 2
        tanzu version || return 1
        printf "\n\n"
        if [[ -n $extracteddirname ]]
        then
            tanzu plugin list || return 1
        else
            tanzu plugin list --local tanzu/ || return 1
        fi
        
        printf "Tanzu CLI...COMPLETED\n\n"
    else
        tanzu version
    fi
    cd ~
    return 0
}