if [ ! ${AWS_REGION} ]; then
  echo "Please set AWS_REGION..."
  exit 1
fi
if [ ! ${THING_NAME} ]; then
  echo "Please set THING_NAME..."
  exit 1
fi

DEVICE_FLEET_NAME=${PROJECT_NAME}-GreengrassDeviceFleet
RESULTS_BUCKET_NAME=${PROJECT_NAME}-sagemaker-inference-results
DEVICE_NAME=${PROJECT_NAME}-SagemakerGreengrassDevice

aws s3 mb s3://${RESULTS_BUCKET_NAME} --region ${AWS_REGION}
echo "Inference results s3 bucket created"
sleep 10

# Create device fleet
aws sagemaker create-device-fleet --region ${AWS_REGION} --device-fleet-name ${DEVICE_FLEET_NAME} \
  --role-arn ${ROLE_ARN} --output-config "{\"S3OutputLocation\":\"s3://${RESULTS_BUCKET_NAME}/\"}" \
  --no-enable-iot-role-alias
echo "Sagemaker device fleet created"

# Register device
aws sagemaker register-devices --region $AWS_REGION --device-fleet-name ${DEVICE_FLEET_NAME} \
  --devices "[{\"DeviceName\":\"${DEVICE_NAME}\",\"IotThingName\":\"${THING_NAME}\"}]"
echo "Sagemaker device registered"
