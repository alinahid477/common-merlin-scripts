#!/bin/bash

version=v0.9.1
downloadlink="https://github.com/vmware-tanzu/tanzu-cli/releases/download/$version/tanzu-cli-linux-amd64.tar.gz"
curl -o /tmp/ -L $downloadlink
curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o /tmp/download-common-scripts.sh && chmod +x /tmp/download-common-scripts.sh
/tmp/download-common-scripts.sh tanzucli /tmp/ && chmod +x /tmp/install-tanzu-cli.sh
/tmp/install-tanzu-cli.sh /tmp
