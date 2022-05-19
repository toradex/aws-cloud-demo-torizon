echo "Syncing system time with www.baidu.com"
DATE_STR=$(curl -I www.baidu.com | grep Date)
echo ${DATE_STR:5}
date -s "${DATE_STR:5}"

if [ ! ${AWS_REGION} ]; then
  echo "Please set AWS_REGION..."
  exit 1
fi
aws configure set region ${AWS_REGION}

if [ ! ${PROJECT_NAME} ]; then
  echo "Please set PROJECT_NAME(one uniqe string with lowercase letters only)..."
  exit 1
fi

source ./01_create_greengrass_core.sh
echo "THING_NAME=${THING_NAME}" >> project_config.sh
echo "CERT_ARN=${CERT_ARN}" >> project_config.sh
echo "THING_GROUP=${THING_GROUP}" >> project_config.sh
echo "THING_POLICY=${THING_POLICY}" >> project_config.sh
echo "THING_GROUP_ARN=${THING_GROUP_ARN}" >> project_config.sh
echo "IOT_DATA_ENDPOINT=${IOT_DATA_ENDPOINT}" >> project_config.sh
echo "IOT_CRED_ENDPOINT=${IOT_CRED_ENDPOINT}" >> project_config.sh

ROLE_ALIAS_NAME=${PROJECT_NAME}_GreengrassCoreRoleAlias
ROLE_ALIAS_POLICY_NAME=${PROJECT_NAME}_GreengrassCoreRoleAliasPolicy
aws iot attach-policy --policy-name ${ROLE_ALIAS_POLICY_NAME} --target ${CERT_ARN}

source ./07_setup_device_greengrass.sh
