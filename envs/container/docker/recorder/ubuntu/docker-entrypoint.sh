#!/bin/sh
set -e
mkdir /chunks 2> /dev/null  || true

cat <<EOF > /ingestionloop.sh
#!/bin/bash
while [ : ]
do
  folder=\$(date  +"%Y-%m-%d-%T")
  mkdir /chunks/\$folder
  #
  # if PERIOD = 0 segementation per Iframe
  #
  if [ \$PERIOD -eq 0 ]; 
  then
    #cmd="/usr/bin/ffmpeg -hide_banner -v error  -f flv -i \$INPUT_URL -acodec copy -f segment -vcodec copy -reset_timestamps 1 -strftime 1 \"/chunks/\$folder/%Y-%m-%d_%H-%M-%S_chunk.mp4\" "
    #cmd="/usr/bin/ffmpeg -hide_banner -v error -rtsp_transport tcp -use_wallclock_as_timestamps 1 -i \$INPUT_URL  -c copy -copyts -vsync passthrough -bsf:v h264_mp4toannexb -f segment -strftime 1 \"/chunks/\$folder/live_%Y-%m-%d_%H-%M-%S_chunk.mp4\""
    #cmd="/usr/bin/ffmpeg -hide_banner -v error -rtsp_transport tcp  -use_wallclock_as_timestamps 1 -i \$INPUT_URL  -r 25 -codec:v libx264  -codec:a aac  -ac 2  -ar 48k  -f segment   -preset fast  -segment_time 4 -force_key_frames  \"expr: gte(t, n_forced * 4)\" -copyts -strftime 1  \"/chunks/\$folder/live_%Y-%m-%d_%H-%M-%S_chunk.mp4\""
    cmd="/usr/bin/ffmpeg -hide_banner -v error -rtsp_transport tcp  -use_wallclock_as_timestamps 1 -i \$INPUT_URL  -r 25 -codec:v libx264 -bsf:v h264_mp4toannexb -codec:a aac  -ac 2  -ar 48k  -f segment   -preset fast  -segment_time 4 -force_key_frames  \"expr: gte(t, n_forced * 4)\" -copyts -strftime 1  \"/chunks/\$folder/live_%Y-%m-%d_%H-%M-%S_chunk.mp4\""
  else  
    # cmd="/usr/bin/ffmpeg  -hide_banner -v error -f flv -i \$INPUT_URL -c copy -flags +global_header -f segment -segment_time \$PERIOD  -segment_format_options movflags=+faststart -reset_timestamps 1 -strftime 1 \"/chunks/\$folder/%Y-%m-%d_%H-%M-%S_chunk.mp4\" "
    #cmd="/usr/bin/ffmpeg -hide_banner -v error -rtsp_transport tcp -use_wallclock_as_timestamps 1 -i \$INPUT_URL  -c copy -copyts -vsync passthrough -bsf:v h264_mp4toannexb -f segment -segment_time \$PERIOD -strftime 1 \"/chunks/\$folder/live_%Y-%m-%d_%H-%M-%S_chunk.mp4\""
    #cmd="/usr/bin/ffmpeg -hide_banner -v error -rtsp_transport tcp  -use_wallclock_as_timestamps 1 -i \$INPUT_URL  -r 25 -codec:v libx264  -codec:a aac  -ac 2  -ar 48k  -f segment   -preset fast  -segment_time \$PERIOD -force_key_frames  \"expr: gte(t, n_forced * \$PERIOD)\" -copyts -strftime 1  \"/chunks/\$folder/live_%Y-%m-%d_%H-%M-%S_chunk.mp4\""
    cmd="/usr/bin/ffmpeg -hide_banner -v error -rtsp_transport tcp  -use_wallclock_as_timestamps 1 -i \$INPUT_URL  -r 25 -codec:v libx264 -bsf:v h264_mp4toannexb -codec:a aac  -ac 2  -ar 48k  -f segment   -preset fast  -segment_time \$PERIOD -force_key_frames  \"expr: gte(t, n_forced * \$PERIOD)\" -copyts -strftime 1  \"/chunks/\$folder/live_%Y-%m-%d_%H-%M-%S_chunk.mp4\""
  fi
  echo "\$cmd"
  eval "\$cmd"
  sleep 5
done
EOF
chmod 0755 /ingestionloop.sh

cat <<'END_HELP' > /uploadloop.sh
#!/bin/bash
while [ : ]
do
  for mp in /chunks/**/liveready_*.mp4
  do
    if [ $mp != '/chunks/**/liveready_*.mp4' ];
    then
      uploadbasetime=$(date +%s%N)
      sourcedir=$(dirname ${mp})
      destdir=$(echo $sourcedir | sed 's/\/chunks//')
      echo "UPLOAD: file: $mp sourcedir: $sourcedir destdir: $destdir"
      pushd "$sourcedir" > /dev/null 
      ls liveready_*.mp4 > $sourcedir/list.txt
      filesize=$(wc -c "$sourcedir/list.txt" | awk '{print $1}')
      if [ $filesize != 0 ];
      then
        #azcopy cp "$sourcedir" "$STORAGE_URL$STORAGE_FOLDER$destdir?$STORAGE_SAS_TOKEN" --overwrite=false --list-of-files "$sourcedir/list.txt"  --log-level=ERROR --output-level=quiet
        azcopy cp "$sourcedir" "$STORAGE_URL$STORAGE_FOLDER?$STORAGE_SAS_TOKEN" --overwrite=false --list-of-files "$sourcedir/list.txt"  --log-level=ERROR --output-level=quiet
        for eachfile in $(cat $sourcedir/list.txt) 
        do    
          echo "UPLOAD: Remove file: $eachfile" 
          rm -f "$eachfile"
        done
      fi
      popd > /dev/null
      echo "UPLOAD: runtime upload file $mp to $STORAGE_URL$STORAGE_FOLDER$destdir?$STORAGE_SAS_TOKEN: $(echo "scale=3;($(date +%s%N) - ${uploadbasetime})/(1*10^09)" | bc) seconds"
    fi
  done
  sleep 1
done
END_HELP
chmod 0755 /uploadloop.sh

cat <<EOF > /convertloop.sh
#!/bin/bash
while [ : ]
do
    for mp in /chunks/**/live_*.mp4
    do
      if [ \$mp != '/chunks/**/live_*.mp4' ];
      then
        lsof | grep \$mp
        if [ ! \${?} -eq 0 ];
        then
          convertbasetime=$(date +%s%N)
          #echo "CONVERT: start time: \$convertbasetime"
          #echo "CONVERT: Found file:  \$mp"
          eval \$(/usr/bin/ffprobe  -v error -hide_banner  -i "\$mp"  -show_entries frame=pkt_pts_time -read_intervals "%+#1" | grep pkt_pts_time | head -n 1)
          if [ ! -z "\$pkt_pts_time" ]; 
          then
            prefix=\$(echo "\$mp"| cut -d'_' -f 1)
            newfile="\$prefix"ready_"\$pkt_pts_time.mp4"
            mv "\$mp" "\$newfile"
            echo "CONVERT: Rename file: \$mp to \$newfile"
            echo "CONVERT: runtime: \$(echo "scale=3;(\$(date +%s%N) - \${convertbasetime})/(1*10^09)" | bc) seconds"
          fi
        else
          echo "CONVERT: Chunk file \$mp still opened"
        fi
      fi
    done
    sleep 1
done
EOF
chmod 0755 /convertloop.sh

echo "Start upload process"
/uploadloop.sh & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start upload process: $status"
  exit $status
fi

echo "Start convert process"
/convertloop.sh & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start convert process: $status"
  exit $status
fi

echo "Start ingestion process"
/ingestionloop.sh & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start ingestion process: $status"
  exit $status
fi

# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

echo "Wait for the end of process"
while sleep 60; do
  ps aux |grep convertloop |grep -q -v grep
  PROCESS_1_STATUS=$?
  ps aux |grep uploadloop |grep -q -v grep
  PROCESS_2_STATUS=$?
  ps aux |grep ingestionloop |grep -q -v grep
  PROCESS_3_STATUS=$?
  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 -o $PROCESS_3_STATUS -ne 0 ]; then
    if [[ $PROCESS_1_STATUS -ne 0 ]] ; then echo "convert process stopped"; fi
    if [[ $PROCESS_2_STATUS -ne 0 ]] ; then echo "upload process stopped"; fi
    if [[ $PROCESS_3_STATUS -ne 0 ]] ; then echo "ingestion process stopped"; fi
    echo "One of the processes has already exited. Stopping the container"
    exit 1
  fi
done

