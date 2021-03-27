#!/bin/bash
export AWS_SDK_LOAD_CONFIG=1
export AWS_PROFILE=hackaton
export AWS_REGION=us-east-1
function deploy_aws {
    sh ./aws/create_instance.sh "1" "Etheriu36" "Etherium_vpc" "Etherium_sub"
}

function help {
    echo "The script is designed to facilitate and speed up"
    echo "options:"
    echo
    echo "  h              Print this Help."
    echo "  deploy         Apply beating from env.yaml to cluster."

    echo

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