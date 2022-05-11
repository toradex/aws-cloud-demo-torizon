echo "Syncing system time with www.baidu.com"
DATE_STR=$(curl -I www.baidu.com | grep Date)
echo ${DATE_STR:5}
date -s "${DATE_STR:5}"


source ./project_config.sh

echo "Cancelling greengrass deployment"
aws greengrassv2 cancel-deployment --deployment-id ${DEPLOYMENT_ID}

echo "Deleting greengrass components"
aws greengrassv2 delete-component --arn ${MODEL_COMPONENT_ARN_V1}
aws greengrassv2 delete-component --arn ${MODEL_COMPONENT_ARN_V2}
aws greengrassv2 delete-component --arn ${CAMERA_COMPONENT_ARN}

CERTIFICATE_ID="${CERT_ARN##*cert/}"
echo "Detaching and deleting iot certificate"
aws iot detach-thing-principal --thing-name ${THING_NAME} --principal ${CERT_ARN}
aws iot update-certificate --certificate-id ${CERTIFICATE_ID} --new-status INACTIVE
aws iot delete-certificate --certificate-id ${CERTIFICATE_ID} --force-delete

echo "Deleting greengrass thing,thing group and thing policy"
aws iot delete-thing-group --thing-group-name ${THING_GROUP}
aws iot delete-thing --thing-name ${THING_NAME}
aws iot delete-policy --policy-name ${THING_POLICY}

echo "Deleting greengrass role alias and policy"
aws iot delete-role-alias --role-alias ${ROLE_ALIAS_NAME}
aws iot delete-policy --policy-name ${ROLE_ALIAS_POLICY_NAME} 

echo "Deleting sagemaker edge device and device fleet"
aws sagemaker deregister-devices --device-fleet-name ${DEVICE_FLEET_NAME} --device-names ${DEVICE_NAME}
aws sagemaker delete-device-fleet --device-fleet-name ${DEVICE_FLEET_NAME}

echo "Deleting IAM role and policy"
aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn ${ROLE_POLICY_ARN}
aws iam delete-policy --policy-arn ${ROLE_POLICY_ARN}
aws iam delete-role --role-name ${ROLE_NAME}

echo "Removing s3 buckets"
aws s3 rb s3://${COMPONENTS_BUCKET_NAME} --force
aws s3 rb s3://${RESULTS_BUCKET_NAME} --force

