#!/bin/sh
set -ef

for i in $(echo $STREAM_LIST | sed 's/,/ /g')
do
    STREAM_ID=$i
done

openssl req -x509 -nodes -days 365 -subj "/C=CA/ST=QC/O=$COMPANYNAME, Inc./CN=$HOSTNAME" -addext "subjectAltName=DNS:$HOSTNAME" -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt;
echo '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Live Streaming</title>
    <link href="//vjs.zencdn.net/7.8.2/video-js.min.css" rel="stylesheet">
    <script src="//vjs.zencdn.net/7.8.2/video.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/videojs-contrib-eme@3.7.0/dist/videojs-contrib-eme.min.js"></script>
 </head>
 <body>
<video id="player" class="video-js vjs-default-skin" height="360" width="640" controls preload="none">' > /usr/local/nginx/html/player.html

for i in $(echo $STREAM_LIST | sed 's/,/ /g')
do
    echo '<source id="source" src="http://'$HOSTNAME:$PORT_HLS'/hls/'$i'.m3u8" type="application/x-mpegURL" />' >> /usr/local/nginx/html/player.html
    break
done

echo '</video>
 <script>
    var player = videojs("#player", {
        controls: true,
        autoplay: false,
        muted: true,
        liveui: true,
        liveTracker: true,
        html5: {
            hls: {
                overrideNative: true
            }
        }
    });

    if(player){
        var tracker = player.liveTracker;
        if(tracker)
        {
            player.on(tracker, "liveedgechange", () => {getCurrentTime()});
            player.on(tracker, "seekableendchange", () => {getCurrentTime()}); 
            player.on("timeupdate", () => {getCurrentTime()}); 

        }
    }

    function getCurrentTime () {
    let currentTime = document.getElementById("timer");
    currentTime.innerHTML = formatTime(tracker.liveCurrentTime());
    }

    function formatTime (time) {
        return (Math.round(time * 1000000) / 1000000).toFixed(6);
    }

    function myFunction(url) {      
      player.src({ type: "application/x-mpegURL", src: url });
      player.load();
      player.play();
    }     
 </script>
 <p>TimeStamp: <span id="timer"></span></p>
 </body>
 <p>URLS: </p>
<select onChange="myFunction(this.options[this.selectedIndex].value)">'   >> /usr/local/nginx/html/player.html

for i in $(echo $STREAM_LIST | sed 's/,/ /g')
do
    echo '<option value="http://'$HOSTNAME':'$PORT_HLS'/hls/'$i'.m3u8">'$i'</option>' >> /usr/local/nginx/html/player.html
done

echo ' </select><p>HOSTNAME: '$HOSTNAME'</p>
 <p>PORT_HTTP: '$PORT_HTTP' - URL: 'http://$HOSTNAME:$PORT_HTTP/player.html'</p>
 <p>PORT_SSL: '$PORT_SSL' - URL: 'https://$HOSTNAME:$PORT_SSL/player.html'</p>'  >> /usr/local/nginx/html/player.html

for i in $(echo $STREAM_LIST | sed 's/,/ /g')
do
 echo '<p>PORT_RTMP: '$PORT_RTMP' - URL: 'rtmp://$HOSTNAME:$PORT_RTMP/live/$i'</p> 
 <p>PORT_HLS: '$PORT_HLS' - URL: 'http://$HOSTNAME:$PORT_HLS/hls/$i.m3u8'</p>
 <p>PORT_DASH: '$PORT_HLS' - URL: 'http://$HOSTNAME:$PORT_HLS/dash/$i.mpd'</p>
 <p>PORT_RTSP: '$PORT_RTSP' - URL: 'rtsp://$HOSTNAME:$PORT_RTSP/rtsp/$i'</p> ' >> /usr/local/nginx/html/player.html
done
echo '</html>' >> /usr/local/nginx/html/player.html


mkdir /var/www 2> /dev/null  || true
mkdir /var/www/html 2> /dev/null  || true
mkdir /var/www/html/rtmp 2> /dev/null  || true
cp /etc/nginx/stat.xsl  /var/www/html/rtmp/stat.xsl 2> /dev/null  || true
mkdir /var/www/html/stream 2> /dev/null  || true
mkdir /var/www/html/stream/hls 2> /dev/null  || true
mkdir /var/www/html/stream/dash 2> /dev/null  || true
echo "worker_processes  1;
error_log  /testav/log/nginxerror.log error;
events {
    worker_connections  1024;
 }
http {
    include       mime.types;
    default_type  application/octet-stream;
    keepalive_timeout  65;
    tcp_nopush on;
    directio 512;
    server {
        sendfile        on;
        listen       "$PORT_HTTP" default_server;
        listen [::]:$PORT_HTTP default_server;
        server_name  $HOSTNAME;
        listen "$PORT_SSL" ssl default_server;
        listen [::]:$PORT_SSL ssl http2 default_server;
        ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
        ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;

        # rtmp stat
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }
        location /stat.xsl {
            root /var/www/html/rtmp;
        }        
        location /control {
            rtmp_control all;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
    server {
        sendfile        off;
        listen "$PORT_HLS";
        location / {
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length';
            if (\$request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*';
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain charset=UTF-8';
                add_header 'Content-Length' 0;
                return 204;
            }
            types {
                application/dash+xml mpd;
                video/mp4 mp4;
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;                                
            }
            root /var/www/html/stream;
            
        }
    }
 }
rtmp {
    server {
        listen "$PORT_RTMP";
        ping 30s;
        notify_method get;
        buflen 5s;
        chunk_size 4000;
        application live {
            live on;
            interleave on;
            hls on;
            #hls_path /mnt/live/;
            hls_path /var/www/html/stream/hls;          
            hls_fragment 3;
            hls_playlist_length 60;

            dash on;
            # dash_path /mnt/dash/;  
            dash_path /var/www/html/stream/dash;          
        }
    }
}" > /etc/nginx/nginx.conf

# Start the nginx process
/usr/local/nginx/sbin/nginx -g "daemon off;" & 
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start nginx: $status"
  exit $status
fi

# Start the rtsp process
export RTSP_PROTOCOLS=tcp 
export RTSP_RTSPPORT=$PORT_RTSP
/usr/local/bin/rtsp-simple-server &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start rtsp: $status"
  exit $status
fi

cat <<EOF > /ffmpegloop.sh
#!/bin/bash
if [ ! -z \$1 ] && [ ! -z \$2 ] && [ ! -z \$3 ] ; 
then
    port_rtmp=\$1
    port_rtsp=\$2
    stream=\$3
    while [ : ]
    do
    echo "Start ffmpeg : rtmp://127.0.0.1:\$port_rtmp/live/\$stream to rtsp://127.0.0.1:\$port_rtsp/rtsp/\$stream"
    #ffmpeg   -hide_banner -loglevel error -i rtmp://127.0.0.1:\$port_rtmp/live/\$stream -codec copy -bsf:v h264_mp4toannexb -rtsp_transport tcp -f rtsp  rtsp://127.0.0.1:\$port_rtsp/rtsp/\$stream
    ffmpeg -hide_banner -loglevel error -i rtmp://127.0.0.1:\$port_rtmp/live/\$stream -codec copy -bsf:v h264_mp4toannexb -rtsp_transport tcp -f rtsp  rtsp://127.0.0.1:\$port_rtsp/rtsp/\$stream
    sleep 1
    done
fi
EOF
chmod 0755 /ffmpegloop.sh

echo "Start the ffmpeg process $STREAM_LIST "
for i in $(echo $STREAM_LIST | sed 's/,/ /g')
do
    # Start the ffmpeg process
    #ffmpeg  -i rtmp://127.0.0.1:1935/live/stream  -framerate 25 -video_size 640x480  -pix_fmt yuv420p -bsf:v h264_mp4toannexb -profile:v baseline -level:v 3.2 -c:v libx264 -x264-params keyint=120:scenecut=0 -c:a aac -b:a 128k -ar 44100 -f rtsp -muxdelay 0.1 rtsp://127.0.0.1:8554/test 
    #ffmpeg  -i rtmp://127.0.0.1:1935/live/stream  -f rtsp  rtsp://127.0.0.1:8554/test &
    #ffmpeg   -hide_banner -loglevel error -i rtmp://127.0.0.1:$PORT_RTMP/live/$i   -codec copy -bsf:v h264_mp4toannexb -f rtsp  rtsp://127.0.0.1:$PORT_RTSP/rtsp/$i &
    /ffmpegloop.sh $PORT_RTMP $PORT_RTSP $i &  
done



# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

while sleep 60; do
  ps aux |grep nginx |grep -q -v grep
  PROCESS_1_STATUS=$?
  ps aux |grep rtsp-simple-server |grep -q -v grep
  PROCESS_2_STATUS=$?
  ps aux |grep ffmpeg |grep -q -v grep
  PROCESS_3_STATUS=$?
  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 -o $PROCESS_3_STATUS -ne 0 ]; then
    if [[ $PROCESS_1_STATUS -ne 0 ]] ; then echo "nginx process stopped"; fi
    if [[ $PROCESS_2_STATUS -ne 0 ]] ; then echo "rtsp-simple-server process stopped"; fi
    if [[ $PROCESS_3_STATUS -ne 0 ]] ; then echo "ffmpeg process stopped"; fi
    echo "One of the processes has already exited. Stopping the container"
    exit 1
  fi
done

