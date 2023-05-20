#!/bin/bash

# usage: 
# code: $HOME/binaries/scripts/tiktok-progress.sh $$ 7200 "image-relocation" & progressloop_pid=$!
# code: your process
# code: kill "$progressloop_pid" > /dev/null 2>&1 || true
# usedin: installtappackagerespository.sh
# eg: $HOME/binaries/scripts/tiktok-progress.sh 
#    - parent_processid ($$ gives you current script's process id) 
#    - max_number_of_secs the tiktok loop 
#    - name_of_process to display




tiktok() {
    local bigcount=1
    local count=1
    local parentprocessid=$1
    local totalbigcount=$2    
    local processname=$3
    if [[ -z $totalbigcount ]]
    then
        totalbigcount=7200 # default 2hrs
    fi
    printf "\nStarting progress check for $processname. Total tolerance: $totalbigcount...\n"
    while [[ $bigcount < $totalbigcount ]]; do
        if [[ $count == 60 ]]
        then
            local isexist=$(ps -ef | grep $parentprocessid | awk '{print $2}' | grep -w $parentprocessid)
            if [[ -z $isexist ]]
            then
                return 1
            fi
            ((bigcount=bigcount+count))
            printf "\nstill processing $processname. Please be patient...(tolerance: $bigcount of $totalbigcount, next check in 60s)...\n"
            count=1
        fi
        printf "."
        ((count=count+1))
        sleep 1
    done
    printf "\nprogress count exceeded tolerance\n"
}

tiktok $1 $2 $3