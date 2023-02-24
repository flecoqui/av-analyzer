ARG AV_RTSP_SERVER_PORT_RTSP=554
ARG AV_RTSP_SERVER_FILE_LIST=camera-300s.mkv

##############################
# Build the rtsp-server-build image.
FROM ubuntu:20.04 as build-rtsp

# Build dependencies.
RUN apt-get -y update  \
  && apt-get -y install  build-essential curl wget

RUN cd /tmp && \
  wget https://github.com/aler9/rtsp-simple-server/releases/download/v0.20.2/rtsp-simple-server_v0.20.2_linux_amd64.tar.gz && \
  tar xvfz rtsp-simple-server_v0.20.2_linux_amd64.tar.gz && \
  cp ./rtsp-simple-server /usr/local/bin/ && \
  cp ./rtsp-simple-server.yml /usr/local/bin/ 

# Cleanup.
RUN rm -rf /var/cache/* /tmp/*

##########################
# Build the release image.
FROM ubuntu:20.04

ARG AV_RTSP_SERVER_PORT_RTSP
ARG AV_RTSP_SERVER_FILE_LIST

ENV PORT_RTSP $AV_RTSP_SERVER_PORT_RTSP
ENV FILE_LIST $AV_RTSP_SERVER_FILE_LIST
ENV RTSP_PROTOCOLS "tcp" 
ENV RTSP_RTSPPORT $PORT_RTSP
ENV RTSP_RTSPADDRESS :$PORT_RTSP

RUN apt-get -y update  \
  && apt-get -y install \
  ffmpeg \
  curl wget

COPY --from=build-rtsp /usr/local/bin/rtsp-simple-server /usr/local/bin/rtsp-simple-server 
COPY --from=build-rtsp /usr/local/bin/rtsp-simple-server.yml /usr/local/bin/rtsp-simple-server.yml 
RUN sed -i 's/rtmpDisable: no/rtmpDisable: yes/g'  /usr/local/bin/rtsp-simple-server.yml 
RUN sed -i 's/hlsDisable: no/hlsDisable: yes/g'  /usr/local/bin/rtsp-simple-server.yml

WORKDIR /live/mediaServer

ADD ./camera-300s.mkv /live/mediaServer/media/
ADD ./camera-300s.mp4 /live/mediaServer/media/
ADD ./sfence1.mp4 /live/mediaServer/media/
ADD ./sfence2.mp4 /live/mediaServer/media/
ADD ./sfence3.mp4 /live/mediaServer/media/
ADD ./sfence4.mp4 /live/mediaServer/media/


COPY docker-entrypoint.sh /
RUN chmod 0755 /docker-entrypoint.sh 

EXPOSE $PORT_RTSP/tcp

CMD /docker-entrypoint.sh