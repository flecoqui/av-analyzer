#!/bin/sh
set -e

cmd="cat /usr/share/nginx/html/config.json  | jq -r '.cameraUrlPrefix = \"${WEBAPP_STREAM_URL_PREFIX}\"' > tmp.$$.json && mv tmp.$$.json /usr/share/nginx/html/config.json"
eval "$cmd"  

echo "server {
    listen $WEBAPP_PORT_HTTP;

    location / {
      root /usr/share/nginx/html;
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

