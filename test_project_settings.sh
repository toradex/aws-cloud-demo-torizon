AWS_REGION="us-west-2"
# PROJECT_NAME is a unique string with lowercase letters only.
PROJECT_NAME="dlr-demo-torizon""-"`date +"%m-%d-%y-%H-%M-%S"`

echo "AWS_REGION=\""$AWS_REGION"\"" > project_settings.sh
echo "PROJECT_NAME=\""$PROJECT_NAME"\"" >> project_settings.sh
echo "DOCKERHUB_LOGIN=\"denisyuji\"" >> project_settings.sh
echo "BOARD_IP=\"verdin-imx8mp-06849027.local\"" >> project_settings.sh
echo "BOARD_PWD=\"1\"" >> project_settings.sh
