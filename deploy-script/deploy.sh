#!/bin/bash
#
set -e
NAME=app
USER=ubuntu
APPLICATION_DIRECTORY=/opt/app/Bolala-code
 
start() {
    echo "Deploying $NAME..."
    echo "Stopping service"
    sudo service $NAME stop
    echo "Changing directory"
    cd $APPLICATION_DIRECTORY
    echo "Getting release"
    sudo -u $USER git pull
    echo "Packagin application"
    activator clean stage
    echo "Starting service"
    sudo service $NAME start
    RETVAL=$?
}

case "$1" in
    start)
        start
        ;;
    *)
        echo "Usage: deploy.sh start"
        exit 1
        ;;
esac
exit $RETVAL
