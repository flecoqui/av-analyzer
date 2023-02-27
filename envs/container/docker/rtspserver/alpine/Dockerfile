ARG ARG_RTSP_SERVER_PORT_RTSP=554

##############################
# Build the rtsp-server-build image.
FROM alpine:3.17.2 as build-rtsp

# Build dependencies.
RUN apk update  \
  && apk add wget

RUN cd /tmp && \
  wget https://github.com/aler9/rtsp-simple-server/releases/download/v0.21.5/rtsp-simple-server_v0.21.5_linux_amd64.tar.gz && \
  tar xvfz rtsp-simple-server_v0.21.5_linux_amd64.tar.gz && \
  cp ./rtsp-simple-server /usr/local/bin/ && \
  cp ./rtsp-simple-server.yml /usr/local/bin/ 

# Cleanup.
RUN rm -rf /var/cache/* /tmp/*

##########################
# Build the release image.
FROM alpine:3.17.2

ARG ARG_RTSP_SERVER_PORT_RTSP

ENV PORT_RTSP $ARG_RTSP_SERVER_PORT_RTSP
ENV RTSP_PROTOCOLS "tcp" 
ENV RTSP_RTSPPORT $PORT_RTSP
ENV RTSP_RTSPADDRESS :$PORT_RTSP

RUN apk update  \
  && apk add ffmpeg \
  && apk add curl \
  && apk add wget

COPY --from=build-rtsp /usr/local/bin/rtsp-simple-server /usr/local/bin/rtsp-simple-server 
COPY --from=build-rtsp /usr/local/bin/rtsp-simple-server.yml /usr/local/bin/rtsp-simple-server.yml 
RUN sed -i 's/rtmpDisable: no/rtmpDisable: yes/g'  /usr/local/bin/rtsp-simple-server.yml 
RUN sed -i 's/hlsDisable: no/hlsDisable: yes/g'  /usr/local/bin/rtsp-simple-server.yml
RUN sed -i 's/webrtcDisable: no/webrtcDisable: yes/g'  /usr/local/bin/rtsp-simple-server.yml

WORKDIR /live/mediaServer

ADD ./input/*.mp4 /live/mediaServer/media/

COPY docker-entrypoint.sh /
RUN chmod 0755 /docker-entrypoint.sh 

EXPOSE $PORT_RTSP/tcp

CMD /docker-entrypoint.sh