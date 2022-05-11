UUID=$(uuidgen)
THING_NAME=${PROJECT_NAME}_GreengrassCore_${UUID:0-8}
THING_GROUP=${PROJECT_NAME}_GreengrassCoreGroup
THING_POLICY=${PROJECT_NAME}_GreengrassThingPolicy_${UUID:0-8}

aws iot create-thing --thing-name ${THING_NAME}
echo "Iot thing ${THING_NAME} created"

mkdir -p greengrass-v2-certs
CERT_ARN=$(aws iot create-keys-and-certificate --set-as-active --certificate-pem-outfile \
   greengrass-v2-certs/device.pem.crt --public-key-outfile greengrass-v2-certs/public.pem.key \
   --private-key-outfile greengrass-v2-certs/private.pem.key | jq -r .certificateArn)
echo "Iot certificate created"

aws iot attach-thing-principal --thing-name ${THING_NAME} --principal $CERT_ARN
aws iot create-policy --policy-name ${THING_POLICY} --policy-document file://greengrass-v2-iot-policy.json
aws iot attach-policy --policy-name ${THING_POLICY} --target $CERT_ARN
echo "Iot thing policy created"

THING_GROUP_ARN=$(aws iot describe-thing-group --thing-group-name ${THING_GROUP} | jq -r .thingGroupArn)
if [ ! ${THING_GROUP_ARN} ]; then
    THING_GROUP_ARN=$(aws iot create-thing-group --thing-group-name ${THING_GROUP} | jq -r .thingGroupArn)
fi
aws iot add-thing-to-thing-group --thing-name ${THING_NAME} --thing-group-name ${THING_GROUP}
echo "Iot thing group created"

IOT_DATA_ENDPOINT=$(aws iot describe-endpoint --endpoint-type iot:Data-ATS | jq -r .endpointAddress)
IOT_CRED_ENDPOINT=$(aws iot describe-endpoint --endpoint-type iot:CredentialProvider | jq -r .endpointAddress)
