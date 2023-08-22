#!/bin/bash

test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true

function helpFunction()
{
    printf "\n"
    echo "Usage:"
    echo -e "\t-o | --launch-octant no value needed. Signals the wizard to start octant."
    echo -e "\t-m | --merge-into-kubeconfig must pass -f or --file parameter. Signals the wizard to execute merging of a new kubeconfig file into the ~/.kube/config file."
    echo -e "\t-r | --remove-from-kubeconfig must pass -n or --name parameter. Signals the wizard to execute removal of a cluster from ~/.kube/config 's users, contexts and clusters segment."
    echo -e "\t-f | --file path to the new kubeconfig file for \"merge-into-kubeconfig\"."
    echo -e "\t-n | --name name to the cluster to be removed from ~/.kube/config file of this docker container."
    echo -e "\t-h | --help"
    printf "\n"
}


unset launchoctant
unset mergeintokubeconfig
unset removefromkubeconfig
unset filename
unset k8sname

# read the options
TEMP=`getopt -o omrf:n:h --long launch-octant,merge-into-kubeconfig,remove-from-kubeconfig,file:,name:,help -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -o | --launch-octant )
            case "$2" in
                "" ) launchoctant='y';  shift 2 ;;
                * ) launchoctant='y' ;  shift 1 ;;
            esac ;;
        -m | --merge-into-kubeconfig )
            case "$2" in
                "" ) mergeintokubeconfig='y'; shift 2 ;;
                * ) mergeintokubeconfig='y' ; shift 1 ;;
            esac ;;
        -r | --remove-from-kubeconfig )
            case "$2" in
                "" ) removefromkubeconfig='y'; shift 2 ;;
                * ) removefromkubeconfig='y' ; shift 1 ;;
            esac ;;
        -f | --file )
            case "$2" in
                "" ) filename=''; shift 2 ;;
                * ) filename=$2 ; shift 1 ;;
            esac ;;
        -n | --name )
            case "$2" in
                "" ) k8sname=''; shift 2 ;;
                * ) k8sname=$2 ; shift 1 ;;
            esac ;;
        -h | --help ) helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done

if [[ $launchoctant == 'y' ]]
then
    source $HOME/binaries/wizards/launch-octant.sh
fi

if [[ $mergeintokubeconfig == 'y' ]]
then
    if [[ -n $filename ]]
    then
        source $HOME/binaries/wizards/merge-into-kubeconfig.sh $filename
    else
        printf "\nERROR: You must supply --file /path/to/new/kubeconfig\n"
    fi
fi

if [[ $removefromkubeconfig == 'y' ]]
then
    if [[ -n $k8sname ]]
    then
        source $HOME/binaries/wizards/remove-from-kubeconfig.sh $k8sname
    else
        printf "\nERROR: You must supply --name name of the cluster in the kubeconfig file\n"
    fi
fi