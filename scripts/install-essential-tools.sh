#!/bin/bash

function downloadKpackCLI () {
    curl -L https://github.com/vmware-tanzu/kpack-cli/releases/download/$(curl -s https://api.github.com/repos/vmware-tanzu/kpack-cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/kp-linux-amd64-$(curl -s https://api.github.com/repos/vmware-tanzu/kpack-cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed -E 's/v//') -o $HOME/essential-clis/kp
}

function downloadKappCLI () {
    curl -L https://github.com/vmware-tanzu/carvel-kapp/releases/download/$(curl -s https://api.github.com/repos/vmware-tanzu/carvel-kapp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/kapp-linux-amd64 -o $HOME/essential-clis/kapp
}

function downloadYttCLI () {
    curl -L https://github.com/vmware-tanzu/carvel-ytt/releases/download/$(curl -s https://api.github.com/repos/vmware-tanzu/carvel-ytt/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/ytt-linux-amd64 -o $HOME/essential-clis/ytt
}

function downloadYqCLI () {
    curl -L  https://github.com/mikefarah/yq/releases/download/$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/yq_linux_amd64 -o $HOME/essential-clis/yq
}

function downloadKrew () {
    local OS="$(uname | tr '[:upper:]' '[:lower:]')"
    local ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
    local KREW="krew-${OS}_${ARCH}"
    curl -L "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" -o $HOME/essential-clis/${KREW}.tar.gz
    cd $HOME/essential-clis/
    tar zxvf "${KREW}.tar.gz"
    mv ${KREW} kubectl-krew
    cd $HOME
}

function installEssentialTools() {

    if [[ ! -d $HOME/essential-clis ]]
    then
        mkdir -p $HOME/essential-clis
    fi

    # incase the tools are installed with carvel tools or some other means during docker build, I need to check if it already exist. 
    # If not then download and install.
    local isexistkp=$(which kp)
    if [[ -z $isexistkp ]]
    then
        printf "installing kpack...\n"
        if [[ ! -f $HOME/essential-clis/kp && ! -f /usr/local/bin/kp ]]
        then
            downloadKpackCLI
        fi
        if [[ ! -f /usr/local/bin/kp ]]
        then
            install $HOME/essential-clis/kp /usr/local/bin/kp
            chmod +x /usr/local/bin/kp
        fi
    fi

    local isexistkapp=$(which kapp)
    if [[ -z $isexistkapp ]]
    then
        printf "installing kapp...\n"
        if [[ ! -f $HOME/essential-clis/kapp && ! -f /usr/local/bin/kapp ]]
        then
            downloadKappCLI
        fi
        if [[ ! -f /usr/local/bin/kapp ]]
        then
            install $HOME/essential-clis/kapp /usr/local/bin/kapp
            chmod +x /usr/local/bin/kapp
        fi
    fi

    local isexistytt=$(which ytt)
    if [[ -z $isexistytt ]]
    then
        printf "installing ytt...\n"
        if [[ ! -f $HOME/essential-clis/ytt && ! -f /usr/local/bin/ytt ]]
        then
            downloadYttCLI
        fi
        if [[ ! -f /usr/local/bin/ytt ]]
        then
            install $HOME/essential-clis/ytt /usr/local/bin/ytt
            chmod +x /usr/local/bin/ytt
        fi
    fi

    local isexistyq=$(which yq)
    if [[ -z $isexistyq ]]
    then
        printf "installing yq...\n"
        if [[ ! -f $HOME/essential-clis/yq && ! -f /usr/local/bin/yq ]]
        then
            downloadYqCLI
        fi
        if [[ ! -f /usr/local/bin/yq ]]
        then
            install $HOME/essential-clis/yq /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
        fi
    fi

    local isexisttree=$(kubectl tree --help)
    if [[ -z $isexisttree ]]
    then
        printf "installing tree (via krew)...\n"
        if [[ ! -f $HOME/essential-clis/kubectl-krew && ! -f /usr/local/bin/kubectl-krew ]]
        then
            downloadKrew
        fi
        if [[ ! -f /usr/local/bin/kubectl-krew ]]
        then
            install $HOME/essential-clis/kubectl-krew /usr/local/bin/kubectl-krew
            chmod +x /usr/local/bin/kubectl-krew

            kubectl krew install tree
        fi
        export PATH="${PATH}:${HOME}/.krew/bin"
        printf "kubectl tree installation..COMPLETE"
    fi
}


function installEssentialToolsLite() {

    if [[ ! -d $HOME/essential-clis ]]
    then
        mkdir -p $HOME/essential-clis
    fi

    # incase the tools are installed with carvel tools or some other means during docker build, I need to check if it already exist. 
    # If not then download and install.
    local isexistkapp=$(which kapp)
    if [[ -z $isexistkapp ]]
    then
        printf "installing kapp...\n"
        if [[ ! -f $HOME/essential-clis/kapp && ! -f /usr/local/bin/kapp ]]
        then
            downloadKappCLI
        fi
        if [[ ! -f /usr/local/bin/kapp ]]
        then
            install $HOME/essential-clis/kapp /usr/local/bin/kapp
            chmod +x /usr/local/bin/kapp
        fi
    fi


    local isexistyq=$(which yq)
    if [[ -z $isexistyq ]]
    then
        printf "installing yq...\n"
        if [[ ! -f $HOME/essential-clis/yq && ! -f /usr/local/bin/yq ]]
        then
            downloadYqCLI
        fi
        if [[ ! -f /usr/local/bin/yq ]]
        then
            install $HOME/essential-clis/yq /usr/local/bin/yq
            chmod +x /usr/local/bin/yq
        fi
    fi
}

# installEssentialTools
# if [ "$(ls -A $HOME/essential-clis)" ]; then
#     echo "Take action $HOME/essential-clis is not Empty"
# else
#     echo "$HOME/essential-clis is Empty"
# fi