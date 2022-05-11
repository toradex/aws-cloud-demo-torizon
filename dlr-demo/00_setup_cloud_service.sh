aws configure set region ${AWS_REGION}
MODEL_NAME=mobilenet-ssd-v2-coco-quant  #^[a-zA-Z0-9](-*[a-zA-Z0-9])
VIDEO_SOURCE="/video_source.mkv"


if [ ! ${PROJECT_NAME} ]; then
  echo "Please set PROJECT_NAME(one uniqe string with lowercase letters only)..."
  exit 1
fi

if [ ${CAMERA_DEVICE} ]; then
  VIDEO_SOURCE=${CAMERA_DEVICE}
fi
echo "The video source is ${VIDEO_SOURCE}"

echo "PROJECT_NAME=${PROJECT_NAME}" > project_config.sh
echo "AWS_REGION=${AWS_REGION}" >> project_config.sh
echo "MODEL_NAME=${MODEL_NAME}" >> project_config.sh

source ./01_create_greengrass_core.sh
echo "THING_NAME=${THING_NAME}" >> project_config.sh
echo "CERT_ARN=${CERT_ARN}" >> project_config.sh
echo "THING_GROUP=${THING_GROUP}" >> project_config.sh
echo "THING_POLICY=${THING_POLICY}" >> project_config.sh
echo "THING_GROUP_ARN=${THING_GROUP_ARN}" >> project_config.sh
echo "IOT_DATA_ENDPOINT=${IOT_DATA_ENDPOINT}" >> project_config.sh
echo "IOT_CRED_ENDPOINT=${IOT_CRED_ENDPOINT}" >> project_config.sh

source ./02_create_greengrass_role.sh
echo "ROLE_ALIAS_NAME=${ROLE_ALIAS_NAME}" >> project_config.sh
echo "ROLE_ALIAS_POLICY_NAME=${ROLE_ALIAS_POLICY_NAME}" >> project_config.sh
echo "ROLE_NAME=${ROLE_NAME}" >> project_config.sh
echo "ROLE_ARN=${ROLE_ARN}" >> project_config.sh
echo "ROLE_POLICY_ARN=${ROLE_POLICY_ARN}" >> project_config.sh

source ./03_create_device_fleet_register_device.sh
echo "DEVICE_FLEET_NAME=${DEVICE_FLEET_NAME}" >> project_config.sh
echo "DEVICE_NAME=${DEVICE_NAME}" >> project_config.sh
echo "RESULTS_BUCKET_NAME=${RESULTS_BUCKET_NAME}" >> project_config.sh

MODULE_URL=mobilenet_ssd_v2_coco_quant_postprocess_person.tgz
MODEL_VERSION=1.0.0       #follow a major.minor.patch number system
source ./04_compile_and_package_neo_model.sh
echo "MODEL_COMPONENT_ARN_V1=${MODEL_COMPONENT_ARN}" >> project_config.sh
echo "COMPONENTS_BUCKET_NAME=${COMPONENTS_BUCKET_NAME}" >> project_config.sh
echo "MODEL_COMPONENT_NAME=${MODEL_COMPONENT_NAME}" >> project_config.sh

MODULE_URL=mobilenet_ssd_v2_coco_quant_postprocess_full.tgz
MODEL_VERSION=2.0.0       #follow a major.minor.patch number system
source ./04_compile_and_package_neo_model.sh
echo "MODEL_COMPONENT_ARN_V2=${MODEL_COMPONENT_ARN}" >> project_config.sh

source ./05_create_inference_component.sh
echo "CAMERA_COMPONENT_ARN=${CAMERA_COMPONENT_ARN}" >> project_config.sh


MODEL_VERSION=1.0.0       #deploy 1.0.0 first
source ./06_create_greengrass_deployment.sh
echo "DEPLOYMENT_ID=${DEPLOYMENT_ID}" >> project_config.sh
