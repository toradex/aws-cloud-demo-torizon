#!/bin/bash
set -e

source ./project_settings.sh

PROJ_NAME='aws-cloud-demo-torizon'

sshpass -p $BOARD_PWD ssh -t torizon@$BOARD_IP "\
  rm -rf /home/torizon/greengrass-*.tar.gz && \
  (echo $BOARD_PWD | sudo -S rm -rf /greengrass) \
  "

sshpass -p $BOARD_PWD scp -r \
  deploy/greengrass-*.tar.gz \
  torizon@$BOARD_IP:/home/torizon/

sshpass -p $BOARD_PWD ssh -t torizon@$BOARD_IP "\
  (echo $BOARD_PWD | sudo -S tar xvf greengrass-*.tar.gz -C / ) \
  "
