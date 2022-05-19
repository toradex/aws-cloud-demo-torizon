set -e

MODULE_URL=https://storage.googleapis.com/download.tensorflow.org/models/tflite_11_05_08/mobilenet_v2_1.0_224_quant.tgz

# echo "Syncing system time with www.baidu.com"
# DATE_STR=$(curl -I www.baidu.com | grep Date)
# echo ${DATE_STR:5}
# date -s "${DATE_STR:5}"


aws --version
if [ $? != 0 ]; then
  echo "awscli command not found, installing...."
  pip3 install awscli
  if [ $? != 0 ]; then
    echo "Failed to install awscli"
    echo "Please reinstall with command \"pip3 install awscli\""
    exit 1
  fi
fi

# if [ ! ${AWS_ACCESS_KEY_ID} ]; then
#   echo "Please set AWS_ACCESS_KEY_ID..."
#   exit 1
# fi
#
# if [ ! ${AWS_SECRET_ACCESS_KEY} ]; then
#   echo "Please set AWS_SECRET_ACCESS_KEY..."
#   exit 1
# fi
#
# if [ ! ${AWS_SESSION_TOKEN} ]; then
#   echo "Please set AWS_SESSION_TOKEN..."
#   exit 1
# fi
#
if [ ! ${AWS_REGION} ]; then
  echo "Please set AWS_REGION..."
  exit 1
fi

if [ ! ${PROJECT_NAME} ]; then
  echo "Please set PROJECT_NAME(one uniqe string with lowercase letters only)..."
  exit 1
fi

source ./00_setup_cloud_service.sh

sleep 30
source ./08_setup_device_greengrass.sh

#sleep 30
#python3 ./check_result.py ${PROJECT_NAME}
