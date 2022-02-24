#!/bin/bash


export $(cat /root/.env | xargs)

installTanzuCLI () {
    printf "\nChecking Tanzu Framework binary..."
    sleep 1
    isinflatedTZ='n'
    DIR="$HOME/tanzu"
    if [ -d "$DIR" ]
    then
        if [ "$(ls -A $DIR)" ]; then
            isinflatedTZ='y'
            printf "\nFound tanzu cli is already inflated in $DIR.\nSkipping further checks.\n"
        fi
    fi
    sleep 1
    if [[ $isinflatedTZ == 'n' ]]
    then
        # default look for: tanzu tap cli
        tarfilenamingpattern="tanzu-framework-linux-amd64*"
        tanzuclibinary=$(ls $HOME/binaries/$tarfilenamingpattern)
        if [[ -z $tanzuclibinary ]]
        then
            # fallback look for: tanzu ent
            tarfilenamingpattern="tanzu-cli-*.tar.*"
            tanzuclibinary=$(ls $HOME/binaries/$tarfilenamingpattern)
        fi
        if [[ -z $tanzuclibinary ]]
        then
            # fallback look for: tanzu tce
            tarfilenamingpattern="tce-*.tar.*"
            tanzuclibinary=$(ls $HOME/binaries/$tarfilenamingpattern)
        fi
        if [[ -z $tanzuclibinary ]]
        then
            printf "\nERROR: tanzu CLI is a required binary for installation.\nYou must place this binary under binaries directory.\n"
            returnOrexit || return 1
        else
            numberoftarfound=$(find $HOME/binaries/$tarfilenamingpattern -type f -printf "." | wc -c)
            if [[ $numberoftarfound -gt 1 ]]
            then
                printf "\nERRR: More than 1 tanzu-framework-linux-amd64.tar found in the binaries directory.\nOnly 1 is allowed.\n"
                returnOrexit || return 1
            fi
        fi
    fi
    printf "COMPLETED\n\n"
    sleep 1

    DIR="$HOME/tanzu"
    if [[ $isinflatedTZ == 'n' && -n $tanzuclibinary ]]
    then
        # at this point we have identified that it has not been untared before. AND we have 1 tar file of tanzu cli distribution
        # let's untar it.
        printf "\nInflating Tanzu CLI...\n"
        sleep 1
        if [ ! -d "$DIR" ]
        then
            printf "Creating new $DIR..."
            mkdir $HOME/tanzu && printf "OK" || printf "FAILED"
            printf "\n"
        else
            if [[ -z $IS_SILENT_MODE && $IS_SILENT_MODE != 'YES' ]]
            then
                printf "$DIR already exits...\n"
                while true; do
                    read -p "Confirm to untar in $DIR [y/n]: " yn
                    case $yn in
                        [Yy]* ) doinflate="y"; printf "\nyou confirmed yes\n"; break;;
                        [Nn]* ) doinflate="n";printf "\n\nYou said no.\n"; break;;
                        * ) echo "Please answer y or n.";;
                    esac
                done
            fi
        fi
        if [[ $doinflate == 'n' ]]
        then
            # user is saying no inflate here. so nothing to do here.
            returnOrexit || return 1;
        fi
        if [ ! -d "$DIR" ]
        then
            printf "\n$DIR does not exist. Not proceed further...\n"
            returnOrexit || return 1
        fi
        printf "\nExtracting $tanzuclibinary in $DIR....\n"
        tar -xvf $tanzuclibinary -C $HOME/tanzu/ || returnOrexit || return 1
        printf "\n$tanzuclibinary extract in $DIR......COMPLETED.\n\n"
    fi

    
    isexist=$(tanzu version)
    if [[ -d $DIR && -z $isexist ]]
    then
        # default check tce
        tcedirname=$(ls $HOME/tanzu/ | grep "v[0-9\.]*$")
        if [[ -n $tcedirname ]]
        then
            # this mean we are dealing with tce tanzu cli.
            printf "\nLinking tanzu cli ($tcedirname)...\n"
            
            cd $HOME/tanzu/$tcedirname || returnOrexit || return 1
            if [[ -d $HOME/.local/share/tanzu-cli ]]
            then
                # This means it was previously installed and all file system exists.
                # just need to link the tanzu binary.
                printf "linking (tce) tanzu..."
                install bin/tanzu /usr/local/bin/tanzu || returnOrexit || return 1
                printf "COMPLETE.\n"
            else
                # TCE Tanzu CLI install
                # This means previously not installed.
                # Linking tanzu binary as part of the install.sh script shipped in the zip file.
                printf "installing (tce) tanzu...\n"
                export ALLOW_INSTALL_AS_ROOT=true
                chmod +x install.sh
                ./install.sh
                unset ALLOW_INSTALL_AS_ROOT
                tanzu plugin list
                printf "\nTanzu CLI installation...COMPLETE.\n\n"
            fi            
        else
            # fallback to tanzu cli TAP or ENT. bellow is same for both of them.
            tanzuframworkVersion=$(ls $HOME/tanzu/cli/core/ | grep "^v[0-9\.]*$")
            if [[ -z $tanzuframworkVersion ]]
            then
                printf "\nERROR: could not found version dir in the $HOME/tanzu/cli/core for tanzu cli.\n"
                returnOrexit || return 1;
            fi
            printf "\nLinking tanzu cli ($tanzuframworkVersion)...\n"
            cd $HOME/tanzu || returnOrexit || return 1
            
            # Link the tanzu binary. Cause that's needs to happen regardless of whether it was previously installed or not.
            install cli/core/$tanzuframworkVersion/tanzu-core-linux_amd64 /usr/local/bin/tanzu || returnOrexit || return 1
            chmod +x /usr/local/bin/tanzu || returnOrexit || return 1

            if [[ ! -d $HOME/.local/share/tanzu-cli ]]
            then
                # This means tanzu cli was NOT previously installed and file system exists. Lets install it.
                if [[ -f cli/manifest.yaml ]]
                then
                    # TAP Tanzu CLI install
                    # This means the previously installed distribution was TAP tanzu cli
                    # the manifest file exist in the case of TAP distribution of TANZU CLI
                    printf "installing tanzu plugin from local..."
                    tanzu plugin install --local cli all || returnOrexit || return 1
                    printf "\nCOMPLETE.\n"
                else
                    # ENT Tanzu CLI install
                    # This means the previously installed distribution was tanzu cli ENT
                    printf "Removing existing plugins from any previous CLI installations..."
                    tanzu plugin clean || returnOrexit
                    printf "COMPLETE.\n"
                    printf "Installing all the plugins for this release..."
                    tanzu plugin sync || returnOrexit
                    printf "COMPLETE.\n"
                fi
                tanzu plugin list
                printf "\nTanzu CLI installation...COMPLETE.\n\n"
            fi
        fi
        
        sleep 2
        tanzu version || returnOrexit
        printf "DONE\n\n"
    fi
    cd ~
    return 0
}