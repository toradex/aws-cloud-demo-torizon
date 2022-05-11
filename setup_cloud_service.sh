#!/bin/bash
set -e

source ./project_settings.sh

rm -rf $PWD/deploy
mkdir deploy

docker build -t $PROJECT_NAME -f setup_cloud_service-Dockerfile .
docker run -it --rm \
  -v $HOME/.aws:/root/.aws \
  -v $PWD/deploy:/deploy \
  -e PROJECT_NAME=$PROJECT_NAME \
  -e AWS_REGION=$AWS_REGION \
  --name $PROJECT_NAME \
  --network host $PROJECT_NAME
