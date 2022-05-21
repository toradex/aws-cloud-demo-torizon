if [ ! ${THING_NAME} ]; then
  echo "Please set THING_NAME..."
  exit 1
fi

STREAM_ARN=$(aws kinesisvideo create-stream --stream-name ${THING_NAME} \
  --data-retention-in-hours 1 )
echo "Kinesis video stream created"
