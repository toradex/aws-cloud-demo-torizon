#!/bin/bash
set -e

source ./project_settings.sh

PROJ_NAME='application'

source ./project_settings.sh

# docker run --rm -it --privileged torizon/binfmt
docker build -f application-Dockerfile -t $DOCKERHUB_LOGIN/$PROJ_NAME .
docker push $DOCKERHUB_LOGIN/$PROJ_NAME

sshpass -p $BOARD_PWD ssh -t torizon@$BOARD_IP "\
  docker pull $DOCKERHUB_LOGIN/$PROJ_NAME && \
  docker run -it --rm --network host \
    -v /dev:/dev \
    -v /tmp:/tmp \
    -v /run/udev/:/run/udev/ \
    -v /greengrass/:/greengrass/ \
    -e PROJECT_NAME=$AWS_PROJECT_NAME \
    --device-cgroup-rule='c 4:* rmw' \
    --device-cgroup-rule='c 13:* rmw' \
    --device-cgroup-rule='c 199:* rmw' \
    --device-cgroup-rule='c 226:* rmw' \
    -e ACCEPT_FSL_EULA=1 \
    --name $PROJ_NAME $DOCKERHUB_LOGIN/$PROJ_NAME"
  "
