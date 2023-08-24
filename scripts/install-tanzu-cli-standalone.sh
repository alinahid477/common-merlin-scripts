#!/bin/bash

version=v0.9.1
filename=tanzu-cli-linux-amd64.tar.gz
downloadlink="https://github.com/vmware-tanzu/tanzu-cli/releases/download/$version/$filename"
printf "\ndownloading tanzu cli binary from github ($downloadlink)...\n"
curl -o /tmp/$filename -L $downloadlink && chmod 766 /tmp/$filename
printf "\ndownloading merlin downloader...\n"
curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o /tmp/download-common-scripts.sh && chmod +x /tmp/download-common-scripts.sh
printf "\ndownloading merlin tanzucli list...\n"
/tmp/download-common-scripts.sh tanzucli /tmp/ /\* && chmod +x /tmp/install-tanzu-cli.sh
printf "\nexecuting /tmp/install-tanzu-cli.sh /tmp...\n"
/tmp/install-tanzu-cli.sh /tmp
