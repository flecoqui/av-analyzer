#!/bin/sh
set -e

# EXemple call to Custom Vision
# curl -i -X POST  --data-binary "@./content/frame.jpg" https://cog-custo-vision-prediction.cognitiveservices.azure.com/customvision/v3.0/Prediction/5d2fb5c1-8273-49b0-8dee-c39b40a6f876/detect/iterations/Iteration1/image -H "Content-Type: application/octet-stream" -H "Prediction-Key: 559d67f5021c410d92b8870f67c56f76"
#   private const string CustomVisionUrl = "https://{0}/customvision/v3.0/Prediction/{1}/detect/iterations/{2}/image";

echo "server {
    listen $CUSTOM_VISION_PORT_HTTP;
    location /score {
        proxy_pass $CUSTOM_VISION_URL;
        proxy_set_header Content-Type application/octet-stream;
        proxy_set_header Prediction-Key $CUSTOM_VISION_KEY;
    } 
}" > /etc/nginx/sites-available/nginx.conf

ln -s /etc/nginx/sites-available/nginx.conf /etc/nginx/sites-enabled/ 2> /dev/null  || true
rm -rf /etc/nginx/sites-enabled/default 2> /dev/null  || true

# Start the nginx process
nginx -g "daemon off;" & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start nginx: $status"
  exit $status
fi


# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

while sleep 60; do
  ps aux |grep nginx |grep -q -v grep
  PROCESS_1_STATUS=$?
  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 ]; then
    if [[ $PROCESS_1_STATUS -ne 0 ]] ; then echo "nginx process stopped"; fi
    echo "One of the processes has already exited. Stopping the container"
    exit 1
  fi
done

