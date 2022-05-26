#!/bin/bash
set -e

source ./project_settings.sh

PROJ_NAME='aws-cloud-demo-torizon'

docker run --rm -it --privileged torizon/binfmt
docker build -f greengrass-Dockerfile -t $DOCKERHUB_LOGIN/$PROJ_NAME .

docker push $DOCKERHUB_LOGIN/$PROJ_NAME

# sshpass -p $BOARD_PWD ssh -t torizon@$BOARD_IP "\
#   docker pull $DOCKERHUB_LOGIN/$PROJ_NAME && \
#   docker run -it --rm --network host \
#     -v /dev:/dev \
#     -v /tmp:/tmp \
#     -v /run/udev/:/run/udev/ \
#     -v /greengrass/:/greengrass/ \
#     --device-cgroup-rule='c 81:* rmw' \
#     --device-cgroup-rule='c 4:* rmw' \
#     --device-cgroup-rule='c 13:* rmw' \
#     --device-cgroup-rule='c 199:* rmw' \
#     --device-cgroup-rule='c 226:* rmw' \
#     -e ACCEPT_FSL_EULA=1 \
#     --name $PROJ_NAME \
#     $DOCKERHUB_LOGIN/$PROJ_NAME"

ssh -t torizon@$BOARD_IP "\
  docker pull $DOCKERHUB_LOGIN/$PROJ_NAME && \
  docker run -it --network host \
    -v /dev:/dev \
    -v /tmp:/tmp \
    -v /run/udev/:/run/udev/ \
    -v /home/torizon/greengrass/:/greengrass/ \
    --device-cgroup-rule='c 81:* rmw' \
    --device-cgroup-rule='c 4:* rmw' \
    --device-cgroup-rule='c 13:* rmw' \
    --device-cgroup-rule='c 199:* rmw' \
    --device-cgroup-rule='c 226:* rmw' \
    -e ACCEPT_FSL_EULA=1 \
    --name $PROJ_NAME \
    $DOCKERHUB_LOGIN/$PROJ_NAME"