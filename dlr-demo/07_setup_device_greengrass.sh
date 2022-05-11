source ./project_config.sh

echo "Setting greengrass configure file"
cp greengrass_config.yaml config.yaml
sed -i "s/GREENGRASS_THING_NAME/${THING_NAME}/g" config.yaml
sed -i "s/IOT_ROLE_ALIAS_NAME/${ROLE_ALIAS_NAME}/g" config.yaml
sed -i "s/IOT_DATA_ENDPOINT/${IOT_DATA_ENDPOINT}/g" config.yaml
sed -i "s/IOT_CRED_ENDPOINT/${IOT_CRED_ENDPOINT}/g" config.yaml
sed -i "s/AWS_REGION/${AWS_REGION}/g" config.yaml

GREENGRASS_ROOT=/greengrass/v2
rm -rf ${GREENGRASS_ROOT}/config/*
rm -rf ${GREENGRASS_ROOT}/logs/*
cp config.yaml ${GREENGRASS_ROOT}/config/
#cp video_source.mkv /

wget https://www.amazontrust.com/repository/AmazonRootCA1.pem -O ${GREENGRASS_ROOT}/AmazonRootCA1.pem
cp greengrass-v2-certs/* ${GREENGRASS_ROOT}

# echo "Restarting greengrass service"
# systemctl restart greengrass
