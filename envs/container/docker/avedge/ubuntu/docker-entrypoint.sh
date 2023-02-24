#!/bin/sh
set -e
mkdir /results 2> /dev/null  || true

cat <<EOF > /extractframeloop.sh
#!/bin/bash
while [ : ]
do
  folder=\$(date  +"%Y-%m-%d-%T")
  mkdir /results/\$folder
  #/usr/bin/ffmpeg -hide_banner  -i \$INPUT_URL  -r 1/$PERIOD  "/results/\$folder/frame-%09d.jpg"
  if [ "\$WAIT_START_FRAME" = "1" ]
  then
    echo EXTRACT: /usr/local/bin/extractframe -i \$INPUT_URL  -e \$PERIOD -o "/results/\$folder/frame-%s.jpg" -s  
    /usr/local/bin/extractframe -i \$INPUT_URL  -e \$PERIOD -o "/results/\$folder/frame-%s.jpg" -s 
  elif [ "\$WAIT_KEY_FRAME" = "1" ]
  then 
    echo EXTRACT: /usr/local/bin/extractframe -i \$INPUT_URL  -e \$PERIOD -o "/results/\$folder/frame-%s.jpg" -k 
    /usr/local/bin/extractframe -i \$INPUT_URL  -e \$PERIOD -o "/results/\$folder/frame-%s.jpg" -k 
  else
    echo EXTRACT: /usr/local/bin/extractframe -i \$INPUT_URL  -e \$PERIOD -o "/results/\$folder/frame-%s.jpg"  
    /usr/local/bin/extractframe -i \$INPUT_URL  -e \$PERIOD -o "/results/\$folder/frame-%s.jpg"  
  fi
  sleep 5
done
EOF
chmod 0755 /extractframeloop.sh

cat <<'END_HELP' > /analyse.sh
#!/bin/bash
if [ ! -z $1 ] && [ ! -z $2 ] ; 
then
  mp=$1
  mpjson=$2
  analysebasetime=$(date +%s%N)
  tmpfile=$(mktemp)
  #echo "Analyzing jpg file: $mp json file: $mpjson"
  #echo "curl -X POST $MODEL_URL -H \"Content-Type: image/jpeg\" --data-binary \"@$mp\" "
  curl -s -X POST $MODEL_URL -H "Content-Type: image/jpeg" --data-binary "@$mp" > $tmpfile
  filesize=$(wc -c "$tmpfile" | awk '{print $1}')
  if [ -f $tmpfile ];
  then
    mv $tmpfile $mpjson
    echo "ANALYSE: runtime analyse of jpg file: $mp json file: $mpjson done in $(echo "scale=3;($(date +%s%N) - ${analysebasetime})/(1*10^09)" | bc) seconds"
  else
    echo "ANALYSE: ERROR result file $mpjson empty: done in $(echo "scale=3;($(date +%s%N) - ${analysebasetime})/(1*10^09)" | bc) seconds"
    rm -f $mp
    rm -f $mpjson
  fi
fi
END_HELP
chmod 0755 /analyse.sh



cat <<'END_HELP' > /analyseloop.sh
#!/bin/bash
while [ : ]
do
  for mp in /results/**/frame-*.jpg
  do
    if [ $mp != '/results/**/frame-*.jpg' ];
    then
      mpjson=${mp%.*}.json
      tmpfile=$(mktemp)
      if [ ! -f $mpjson ];
      then
        /analyse.sh $mp $mpjson &  
      fi
    fi
  done
  sleep 1
done
END_HELP
chmod 0755 /analyseloop.sh

cat <<'END_HELP' > /upload.sh
#!/bin/bash
if [ ! -z $1 ] && [ ! -z $2 ] && [ ! -z $3 ] ; 
then
  uploadbasetime=$(date +%s%N)
  sourcedir=$1
  destdir=$2
  sourcelist=$3 
  pushd "$sourcedir" > /dev/null 
  echo "UPLOAD: files sourcedir: $sourcedir destdir: $destdir"
  #azcopy cp "$sourcedir" "$STORAGE_URL$STORAGE_FOLDER$destdir?$STORAGE_SAS_TOKEN" --overwrite=false --list-of-files "$sourcelist"  --log-level=ERROR --output-level=quiet
  azcopy cp "$sourcedir" "$STORAGE_URL$STORAGE_FOLDER?$STORAGE_SAS_TOKEN" --overwrite=false --list-of-files "$sourcelist"  --log-level=ERROR --output-level=quiet
  for eachfile in $(cat $sourcelist) 
  do    
    echo "UPLOAD: Remove file: $eachfile" 
    rm -f "$eachfile"
  done
  popd > /dev/null
  echo "UPLOAD: runtime upload file $mp to $STORAGE_URL$STORAGE_FOLDER$destdir?$STORAGE_SAS_TOKEN: $(echo "scale=3;($(date +%s%N) - ${uploadbasetime})/(1*10^09)" | bc) seconds"
fi
END_HELP
chmod 0755 /upload.sh

cat <<'END_HELP' > /uploadloop.sh
#!/bin/bash
while [ : ]
do
  for mp in /results/**/frame-*.json
  do
    if [ $mp != '/results/**/frame-*.json' ];
    then
      if [ -f $mp ];
      then
        sourcedir=$(dirname ${mp})
        destdir=$(echo $sourcedir | sed 's/\/results//')
        pushd "$sourcedir" > /dev/null 
        ls frame-*.json > $sourcedir/listjson.txt
        cat $sourcedir/listjson.txt > $sourcedir/list.txt
        for jsonfile in $(cat $sourcedir/listjson.txt); do
            echo ${jsonfile%.*}.jpg >> $sourcedir/list.txt
        done      
        filesize=$(wc -c "$sourcedir/list.txt" | awk '{print $1}')
        if [ $filesize != 0 ];
        then
          /upload.sh $sourcedir $destdir $sourcedir/list.txt  
        fi
        popd > /dev/null
      fi
    fi
  done
  sleep 1
done
END_HELP
chmod 0755 /uploadloop.sh


# Start the extract frame process
echo "Start extract frame process"
/extractframeloop.sh & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start extract frame process: $status"
  exit $status
fi

# Start the analyse process
echo "Start analyse process"
/analyseloop.sh & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start analyse process: $status"
  exit $status
fi

# Start the upload process
echo "Start upload process"
/uploadloop.sh & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start upload process: $status"
  exit $status
fi

# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

echo "Wait for the end of process"
while sleep 60; do
  ps aux |grep extractframeloop |grep -q -v grep
  PROCESS_1_STATUS=$?
  ps aux |grep uploadloop |grep -q -v grep
  PROCESS_2_STATUS=$?
  ps aux |grep analyseloop |grep -q -v grep
  PROCESS_3_STATUS=$?
  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 ]; then
    if [[ $PROCESS_1_STATUS -ne 0 ]] ; then echo "extract frame process stopped"; fi
    if [[ $PROCESS_2_STATUS -ne 0 ]] ; then echo "upload process stopped"; fi
    if [[ $PROCESS_3_STATUS -ne 0 ]] ; then echo "analyse process stopped"; fi
    echo "One of the processes has already exited. Stopping the container"
    exit 1
  fi
done

