#!/bin/bash

version=v0.9.1
filename=tanzu-cli-linux-amd64.tar.gz

if [[ -f /tmp/$filename ]]
then
    printf "\nfound /tmp/$filename. No need to download.\n"
    chmod 766 /tmp/$filename
elif [[ -n $(which tanzu) ]]
then
    printf "\nTanzu CLI is installed. No need to download.\n"
else
    downloadlink="https://github.com/vmware-tanzu/tanzu-cli/releases/download/$version/$filename"
    printf "\ndownloading tanzu cli binary from github ($downloadlink)...\n"
    curl -o /tmp/$filename -L $downloadlink && chmod 766 /tmp/$filename
fi
printf "\ndownloading merlin downloader...\n"
curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o /tmp/download-common-scripts.sh && chmod +x /tmp/download-common-scripts.sh
printf "\ndownloading merlin tanzucli list...\n"
/tmp/download-common-scripts.sh tanzucli scripts /tmp/ && chmod +x /tmp/install-tanzu-cli.sh
printf "\nexecuting /tmp/install-tanzu-cli.sh /tmp...\n"
source /tmp/install-tanzu-cli.sh 
installTanzuCLI /tmp
rm /tmp/$filename || echo "cannot remove /tmp/$filename"
echo "..stand alone tanzu cli installation complete.."