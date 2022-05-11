if [ ! ${AWS_REGION} ]; then
  echo "Please set AWS_REGION..."
  exit 1
fi

if [ ! ${MODEL_COMPONENT_NAME} ]; then
  echo "Please set MODEL_COMPONENT_NAME..."
  exit 1
fi
COMPONENTS_BUCKET_NAME=${PROJECT_NAME}-greengrass-components
CAMERA_COMPONENT_NAME=${PROJECT_NAME}_edgeManagerClientCameraIntegration
aws s3 mb s3://${COMPONENTS_BUCKET_NAME} --region ${AWS_REGION}  || true
echo "Components s3 bucket created"
sleep 10

aws s3api put-object --bucket ${COMPONENTS_BUCKET_NAME} \
  --key artifacts/aws.sagemaker.edgeManagerClientCameraIntegration/0.1.0/agent_pb2_grpc.py \
  --body components/agent_pb2_grpc.py
aws s3api put-object --bucket ${COMPONENTS_BUCKET_NAME} \
  --key artifacts/aws.sagemaker.edgeManagerClientCameraIntegration/0.1.0/agent_pb2.py \
  --body components/agent_pb2.py
aws s3api put-object --bucket ${COMPONENTS_BUCKET_NAME} \
  --key artifacts/aws.sagemaker.edgeManagerClientCameraIntegration/0.1.0/camera_integration_edgemanger_client.py \
  --body components/camera_integration_edgemanger_client.py

COMPONENTS_RECIPE=aws.sagemaker.edgeManagerClientCameraIntegration-0.1.0.yaml
cp components/${COMPONENTS_RECIPE} .
sed -i "s/BUCKET_NAME/${COMPONENTS_BUCKET_NAME}/g" ${COMPONENTS_RECIPE}
sed -i "s/CAMERA_COMPONENT_NAME/${CAMERA_COMPONENT_NAME}/g" ${COMPONENTS_RECIPE}
sed -i "s/MODEL_COMPONENT_NAME/${MODEL_COMPONENT_NAME}/g" ${COMPONENTS_RECIPE}
CAMERA_COMPONENT_ARN=$(aws greengrassv2 create-component-version --inline-recipe fileb://${COMPONENTS_RECIPE} \
  --region $AWS_REGION | jq -r .arn)
echo "Camera greengrass components created"
