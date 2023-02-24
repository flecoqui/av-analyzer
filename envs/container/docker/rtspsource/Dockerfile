# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
ARG AV_RTSP_SOURCE_PORT=8554
FROM ubuntu:18.04

ARG AV_RTSP_SOURCE_PORT

ENV RTSP_SOURCE_PORT $AV_RTSP_SOURCE_PORT 

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends make build-essential wget libssl-dev && \
    wget http://www.live555.com/liveMedia/public/live555-latest.tar.gz && \
    tar -xzf live555-latest.tar.gz && \
    rm live555-latest.tar.gz && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \    
    cd live && \
    ./genMakefiles linux && \
    make && \
    apt-get purge -y --auto-remove gcc libc6-dev make

WORKDIR /live/mediaServer

ADD ./camera-300s.mkv /live/mediaServer/media/

EXPOSE $RTSP_SOURCE_PORT

ENTRYPOINT [ "./live555MediaServer" ]
