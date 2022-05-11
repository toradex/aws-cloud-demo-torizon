if [ ! ${CERT_ARN} ]; then
  echo "Please set CERT_ARN..."
  exit 1
fi

ROLE_NAME=${PROJECT_NAME}_GreengrassSagemakerRole
ROLE_POLICY_NAME=${PROJECT_NAME}_GreengrassSagemakerRolePolicy
ROLE_ALIAS_NAME=${PROJECT_NAME}_GreengrassCoreRoleAlias
ROLE_ALIAS_POLICY_NAME=${PROJECT_NAME}_GreengrassCoreRoleAliasPolicy

if [ ! ${PERMISSIONS_BOUNDARY} ]; then
  ROLE_ARN=$(aws iam create-role --role-name ${ROLE_NAME} \
    --assume-role-policy-document file://device-role-trust-policy.json | jq -r .Role.Arn)
else
  ROLE_ARN=$(aws iam create-role --role-name ${ROLE_NAME} \
    --assume-role-policy-document file://device-role-trust-policy.json \
    --permissions-boundary ${PERMISSIONS_BOUNDARY} | jq -r .Role.Arn)
fi
if [ ! ${ROLE_ARN} ];then
  echo "Create IAM role failed, did you forget to set PERMISSIONS_BOUNDARY arn?"
  exit 1
fi
ROLE_POLICY_ARN=$(aws iam create-policy --policy-name ${ROLE_POLICY_NAME} \
  --policy-document file://device-role-access-policy.json | jq -r .Policy.Arn)
aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn ${ROLE_POLICY_ARN}
echo "IAM role created"

ROLE_ALIAS_ARN=$(aws iot create-role-alias --role-alias ${ROLE_ALIAS_NAME} --role-arn $ROLE_ARN | jq -r .roleAliasArn)
POLICY_JSON="{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"iot:AssumeRoleWithCertificate\",\"Resource\":\"${ROLE_ALIAS_ARN}\"}]}"
aws iot create-policy --policy-name ${ROLE_ALIAS_POLICY_NAME} --policy-document ${POLICY_JSON}
aws iot attach-policy --policy-name ${ROLE_ALIAS_POLICY_NAME} --target ${CERT_ARN}
echo "Greengrass role alias created"
