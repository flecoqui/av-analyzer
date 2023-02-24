# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
ARG AV_MODEL_CUSTOM_VISION_URL=""
ARG AV_MODEL_CUSTOM_VISION_KEY=""
ARG AV_MODEL_CUSTOM_VISION_PORT_HTTP=8081

FROM ubuntu:20.04
ARG AV_MODEL_CUSTOM_VISION_URL
ARG AV_MODEL_CUSTOM_VISION_KEY
ARG AV_MODEL_CUSTOM_VISION_PORT_HTTP

ENV CUSTOM_VISION_PORT_HTTP $AV_MODEL_CUSTOM_VISION_PORT_HTTP
ENV CUSTOM_VISION_URL $AV_MODEL_CUSTOM_VISION_URL
ENV CUSTOM_VISION_KEY $AV_MODEL_CUSTOM_VISION_KEY

# Install python
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends 


# Install runit, nginx
RUN apt-get update -y && \
    apt-get install --no-install-recommends -y wget nginx

COPY docker-entrypoint.sh /
RUN chmod 0755 /docker-entrypoint.sh 

EXPOSE $CUSTOM_VISION_PORT_HTTP/tcp 

CMD /docker-entrypoint.sh
