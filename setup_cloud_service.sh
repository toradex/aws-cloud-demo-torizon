#!/bin/bash
set -e

source ./project_settings.sh

rm -rf $PWD/deploy
mkdir deploy

docker build -t $PROJECT_NAME -f setup_cloud_service-Dockerfile .
docker run -it --rm \
  -v $PWD/deploy:/deploy \
  -e PROJECT_NAME=$PROJECT_NAME \
  -e AWS_REGION=$AWS_REGION \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
  --name $PROJECT_NAME \
  --network host $PROJECT_NAME
