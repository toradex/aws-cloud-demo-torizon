if [ ! ${AWS_REGION} ]; then
  echo "Please set AWS_REGION..."
  exit 1
fi
if [ ! ${ROLE_ARN} ]; then
  echo "Please set ROLE_ARN..."
  exit 1
fi
if [ ! ${MODULE_URL} ]; then
  echo "Please set MODULE_URL..."
  exit 1
fi
if [ ! ${MODEL_VERSION} ]; then
  echo "Please set MODEL_VERSION..."
  exit 1
fi
if [ ! ${MODEL_NAME} ]; then
  echo "Please set MODEL_NAME..."
  exit 1
fi

COMPONENTS_BUCKET_NAME=${PROJECT_NAME}-greengrass-components
UUID=$(uuidgen)
COMPILATION_JOB_NAME=${MODEL_NAME}-${UUID:0-8}
aws s3 mb s3://${COMPONENTS_BUCKET_NAME} --region ${AWS_REGION} || true
echo "Components s3 bucket created"
sleep 10

#Upload model to components bucket
#wget ${MODULE_URL} -O mobilenet_v2_1.0_224_quanta.tgz
echo "Start to create model component version ${MODEL_VERSION}"
aws s3 cp ${MODULE_URL} s3://${COMPONENTS_BUCKET_NAME}/models/uncompiled/${MODEL_VERSION}/mobilenet_ssd_v2_coco_quant_postprocess.tgz
echo "Model has been uploaded to s3"

#Create neo job to compile the model
aws sagemaker create-compilation-job --compilation-job-name ${COMPILATION_JOB_NAME} --role-arn ${ROLE_ARN} \
  --input-config "{\"S3Uri\": \"s3:\/\/${COMPONENTS_BUCKET_NAME}\/models\/uncompiled\/${MODEL_VERSION}\/mobilenet_ssd_v2_coco_quant_postprocess.tgz\",\"DataInputConfig\": \"{\\\"normalized_input_image_tensor\\\":[1,300,300,3]}\",\"Framework\": \"TFLITE\"}" \
  --output-config "{\"S3OutputLocation\":\"s3:\/\/${COMPONENTS_BUCKET_NAME}\/models\/compiled\/${MODEL_VERSION}\/\",\"TargetDevice\":\"imx8mplus\"}" \
  --stopping-condition "{\"MaxWaitTimeInSeconds\":60,\"MaxRuntimeInSeconds\":900}" --region $AWS_REGION

echo "Neo compilation job created, the job will take 5 minuts."
CJOB_STATUS=""
while [ "${CJOB_STATUS}" != "COMPLETED" ]
do
  echo "Waiting compilation job to complete"
  CJOB_STATUS=$(aws sagemaker describe-compilation-job --compilation-job-name ${COMPILATION_JOB_NAME} | jq -r .CompilationJobStatus)
  sleep 30
done


PACKAGING_JOB_NAME=${MODEL_NAME}-${UUID:0-8}
MODEL_COMPONENT_NAME=${PROJECT_NAME}-${MODEL_NAME}

#Create model packageing job
aws sagemaker create-edge-packaging-job --edge-packaging-job-name ${PACKAGING_JOB_NAME} \
  --compilation-job-name ${COMPILATION_JOB_NAME} --model-name ${MODEL_NAME} --model-version ${MODEL_VERSION} \
  --role-arn ${ROLE_ARN} --output-config "{\"S3OutputLocation\":\"s3:\/\/${COMPONENTS_BUCKET_NAME}\/models\/packaged\/${MODEL_VERSION}\/\",\"PresetDeploymentType\":\"GreengrassV2Component\",\"PresetDeploymentConfig\":\"{\\\"ComponentName\\\":\\\"${MODEL_COMPONENT_NAME}\\\",\\\"ComponentDescription\\\":\\\"${PROJECT_NAME} ${MODEL_NAME}\\\",\\\"ComponentVersion\\\":\\\"${MODEL_VERSION}\\\"}\"}" \
  --region $AWS_REGION

echo "Neo packaging job created, the job will take 2 minuts."
PJOB_STATUS=""
while [ "${PJOB_STATUS}" != "COMPLETED" ]
do
  echo "Waiting packaging job to complete"
  PJOB_STATUS=$(aws sagemaker describe-edge-packaging-job --edge-packaging-job-name ${PACKAGING_JOB_NAME} \
    | jq -r .EdgePackagingJobStatus )
  sleep 30
done

MODEL_COMPONENT_ARN=$(aws sagemaker describe-edge-packaging-job \
  --edge-packaging-job-name ${PACKAGING_JOB_NAME} | jq -r .PresetDeploymentOutput.Artifact)
echo "Model component version ${MODEL_VERSION} created"
