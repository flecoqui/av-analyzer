#!/bin/sh
set -ef


cat <<EOF > /rtspserverloop.sh
while [ : ]
do
  echo "Start rtsp server: rtsp-simple-server /usr/local/bin/rtsp-simple-server.yml" 
  /usr/local/bin/rtsp-simple-server /usr/local/bin/rtsp-simple-server.yml 
  status=\$?
  if [ \$status -ne 0 ]; then
    echo "Failed to start rtsp: \$status"
  fi
  sleep 5
done
EOF
chmod 0755 /rtspserverloop.sh

cat <<'END_HELP' > /stream.sh
if [ ! -z $1 ]; 
then
  mp=$(basename $1)
  while [ : ]
  do
    echo "Start ffmpeg streamer: from /live/mediaServer/media/$mp to rtsp://127.0.0.1:$PORT_RTSP/media/$mp" 
    ffmpeg -hide_banner -loglevel error  -re -stream_loop -1 -i /live/mediaServer/media/$mp  -codec copy -use_wallclock_as_timestamps 1 -f rtsp  rtsp://127.0.0.1:$PORT_RTSP/media/$mp 
    status=$?
    if [ $status -ne 0 ]; then
      echo "Failed to start rtsp://127.0.0.1:$PORT_RTSP/media/$mp: $status"
    fi
    sleep 5
  done
fi
END_HELP
chmod 0755 /stream.sh

cat <<EOF > /ffmpegloop.sh
while [ : ]
do
  for i in /live/mediaServer/media/*.mp4
  do
      ps aux |grep \$i |grep -q -v grep
      STREAM_PROCESS_1_STATUS=\$?
      if [ \$STREAM_PROCESS_1_STATUS -ne 0 ]; then
          /stream.sh "\$i" &
      fi
  done
  sleep 5
done
EOF
chmod 0755 /ffmpegloop.sh

echo "Start rtspserver process"
/rtspserverloop.sh & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start rtspserver process: $status"
  exit $status
fi

echo "Start ffmpeg process"
/ffmpegloop.sh & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start ffmpeg process: $status"
  exit $status
fi

# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

while sleep 60; do
  ps aux |grep rtspserverloop |grep -q -v grep
  PROCESS_1_STATUS=$?
  ps aux |grep ffmpegloop |grep -q -v grep
  PROCESS_2_STATUS=$?

  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 ]; then
    if [[ $PROCESS_1_STATUS -ne 0 ]] ; then echo "rtsp-simple-server process stopped"; fi
    if [[ $PROCESS_2_STATUS -ne 0 ]] ; then echo "ffmpeg process stopped"; fi
    echo "One of the processes has already exited. Stopping the container"
    exit 1
  fi
done

