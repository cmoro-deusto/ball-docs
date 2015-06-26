#!/bin/bash
#
set -e
NAME=app
USER=ubuntu
APPLICATION_DIRECTORY=/opt/app/ball-pubapi

check_upstart_service(){
    status $1 | grep -q "^$1 start" > /dev/null
    return $?
}

start() {

    echo "Deploying $NAME..."

    echo "Changing directory"
    cd $APPLICATION_DIRECTORY
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    echo "Local version is: $LOCAL"
    echo "Remote version is: $REMOTE"

    if [ $LOCAL = $REMOTE ]; then
      echo "Release is up to date!"
    else

      echo "Getting release... $REMOTE"

      if check_upstart_service app; 
      then 
        echo "Stopping Service" 
        sudo service $NAME stop;
      fi

      sudo -u $USER git pull
      echo "Packagin application"
      activator clean stage
      echo "Starting service"
      sudo service $NAME start
      RETVAL=$?
    fi
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
