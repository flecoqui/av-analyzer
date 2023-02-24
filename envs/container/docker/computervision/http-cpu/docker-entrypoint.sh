#!/bin/sh
set -e
# EXemple call to Computer Vision
# curl -X POST \"https://to_be_completed.cognitiveservices.azure.com/vision/v3.2/analyze?visualFeatures=Objects&details=Landmarks&language=en&model-version=latest\" -H \"Content-Type: application/octet-stream\" -H \"Ocp-Apim-Subscription-Key: to_be_completed\" --data-binary @output\frame-000000001.jpg

echo "server {
    listen $COMPUTER_VISION_PORT_HTTP;
    location /score {
        proxy_pass $COMPUTER_VISION_URL;
        proxy_set_header Content-Type application/octet-stream;
        proxy_set_header Ocp-Apim-Subscription-Key $COMPUTER_VISION_KEY;
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

