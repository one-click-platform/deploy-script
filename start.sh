#!/bin/bash

function deploy_aws {
    
}

function help {
    echo "The script is designed to facilitate and speed up"
    echo "options:"
    echo
    echo "  h              Print this Help."
    echo "  deploy         Apply beating from env.yaml to cluster."

    echo

}

function test {
    

}

echo
while [ -n "$1" ]
do
case "$1" in
-h)
help;;

-deploy_aws)
deploy_aws;;

-test)
test ;;

esac
shift
done