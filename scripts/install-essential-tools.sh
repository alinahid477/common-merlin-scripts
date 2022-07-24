#!/bin/bash

function downloadKpackCLI () {
    curl -L https://github.com/vmware-tanzu/kpack-cli/releases/download/$(curl -s https://api.github.com/repos/vmware-tanzu/kpack-cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/kp-linux-$(curl -s https://api.github.com/repos/vmware-tanzu/kpack-cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed -E 's/v//') -o $HOME/essential-clis/kp
}

function downloadKappCLI () {
    curl -L https://github.com/vmware-tanzu/carvel-kapp/releases/download/$(curl -s https://api.github.com/repos/vmware-tanzu/carvel-kapp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/kapp-linux-amd64 -o $HOME/essential-clis/kapp
}

function downloadYttCLI () {
    curl -L https://github.com/vmware-tanzu/carvel-ytt/releases/download/$(curl -s https://api.github.com/repos/vmware-tanzu/carvel-ytt/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')/ytt-linux-amd64 -o $HOME/essential-clis/ytt
}

function installEssentialTools() {

    if [[ ! -d $HOME/essential-clis ]]
    then
        mkdir -p $HOME/essential-clis
    fi

    if [[ ! -f $HOME/essential-clis/kp && ! -f /usr/local/bin/kp ]]
    then
        downloadKpackCLI
    fi
    if [[ ! -f /usr/local/bin/kp ]]
    then
        install $HOME/essential-clis/kp /usr/local/bin/kp
        chmod +x /usr/local/bin/kp
    fi

    if [[ ! -f $HOME/essential-clis/kapp && ! -f /usr/local/bin/kapp ]]
    then
        downloadKappCLI
    fi
    if [[ ! -f /usr/local/bin/kapp ]]
    then
        install $HOME/essential-clis/kapp /usr/local/bin/kapp
        chmod +x /usr/local/bin/kapp
    fi

    if [[ ! -f $HOME/essential-clis/ytt && ! -f /usr/local/bin/ytt ]]
    then
        downloadYttCLI
    fi
    if [[ ! -f /usr/local/bin/ytt ]]
    then
        install $HOME/essential-clis/ytt /usr/local/bin/ytt
        chmod +x /usr/local/bin/ytt
    fi
}

# installEssentialTools
# if [ "$(ls -A $HOME/essential-clis)" ]; then
#     echo "Take action $HOME/essential-clis is not Empty"
# else
#     echo "$HOME/essential-clis is Empty"
# fi