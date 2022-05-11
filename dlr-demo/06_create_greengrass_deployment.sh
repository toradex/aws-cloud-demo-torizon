if [ ! ${THING_GROUP_ARN} ]; then
  echo "Please set THING_GROUP_ARN..."
  exit 1
fi
if [ ! ${VIDEO_SOURCE} ]; then
  echo "Please set VIDEO_SOURCE..."
  exit 1
fi
if [ ! ${MODEL_NAME} ]; then
  echo "Please set MODEL_NAME..."
  exit 1
fi
if [ ! ${DEVICE_FLEET_NAME} ]; then
  echo "Please set DEVICE_FLEET_NAME..."
  exit 1
fi
if [ ! ${COMPONENTS_BUCKET_NAME} ]; then
  echo "Please set COMPONENTS_BUCKET_NAME..."
  exit 1
fi
if [ ! ${RESULTS_BUCKET_NAME} ]; then
  echo "Please set RESULTS_BUCKET_NAME..."
  exit 1
fi
if [ ! ${CAMERA_COMPONENT_NAME} ]; then
  echo "Please set RESULTS_BUCKET_NAME..."
  exit 1
fi
if [ ! ${MODEL_COMPONENT_NAME} ]; then
  echo "Please set MODEL_COMPONENT_NAME..."
  exit 1
fi
if [ ! ${MODEL_VERSION} ]; then
  echo "Please set MODEL_VERSION..."
  exit 1
fi


GG_DEPLOYMENT_NAME=${PROJECT_NAME}_Deployment

GG_COMPONENTS="{
         \"aws.greengrass.LegacySubscriptionRouter\": {
             \"componentVersion\": \"2.1.4\"
         },
         \"aws.greengrass.Nucleus\": {
             \"componentVersion\":\"2.5.3\",
             \"configurationUpdate\": {
                 \"merge\": \"{\\\"mqtt\\\":{\\\"port\\\":443}, \\\"greengrassDataPlanePort\\\": 443}\"
             }
         },
         \"aws.greengrass.SageMakerEdgeManager\": {
             \"componentVersion\": \"1.1.0\",
             \"configurationUpdate\": {
                 \"merge\": \"{\\\"CaptureDataPeriodicUpload\\\":\\\"false\\\",\\\"CaptureDataPeriodicUploadPeriodSeconds\\\":\\\"8\\\",\\\"DeviceFleetName\\\":\\\"${DEVICE_FLEET_NAME}\\\",\\\"BucketName\\\":\\\"${RESULTS_BUCKET_NAME}\\\",\\\"CaptureDataBase64EmbedLimit\\\":\\\"3072\\\",\\\"CaptureDataPushPeriodSeconds\\\":\\\"4\\\",\\\"SagemakerEdgeLogVerbose\\\":\\\"false\\\",\\\"CaptureDataBatchSize\\\":\\\"10\\\",\\\"CaptureDataDestination\\\":\\\"Cloud\\\",\\\"FolderPrefix\\\":\\\"sme-capture\\\",\\\"UnixSocketName\\\":\\\"/tmp/sagemaker_edge_agent_example.sock\\\",\\\"CaptureDataBufferSize\\\":\\\"30\\\"}\"
             },
             \"runWith\": {}
         },
         \"aws.greengrass.TokenExchangeService\": {
             \"componentVersion\": \"2.0.3\"
         },
         \"aws.sagemaker.${CAMERA_COMPONENT_NAME}\": {
             \"componentVersion\": \"0.1.0\",
             \"configurationUpdate\": {
                 \"merge\": \"{\\\"streamURL\\\":\\\"${VIDEO_SOURCE}\\\",\\\"modelComponentName\\\":\\\"${MODEL_COMPONENT_NAME}\\\",\\\"modelName\\\":\\\"${MODEL_NAME}\\\",\\\"quantization\\\":\\\"True\\\",\\\"rtspPort\\\":\\\"8554\\\"}\"
             },
             \"runWith\": {}
        },
        \"${MODEL_COMPONENT_NAME}\": {
            \"componentVersion\": \"${MODEL_VERSION}\"
        }}"

DEPLOYMENT_ID=$(aws greengrassv2 create-deployment --target-arn ${THING_GROUP_ARN} \
  --deployment-name ${GG_DEPLOYMENT_NAME} --components "${GG_COMPONENTS}" | jq -r .deploymentId)
echo "Greengrass deployment created"
