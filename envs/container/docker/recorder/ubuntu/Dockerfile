ARG AV_INPUT_URL=""
ARG AV_PERIOD=10
ARG AV_STORAGE_URL=""
ARG AV_STORAGE_SAS_TOKEN=""
ARG AV_STORAGE_FOLDER=""

FROM ubuntu:20.04
ARG AV_INPUT_URL 
ARG AV_PERIOD
ARG AV_STORAGE_URL
ARG AV_STORAGE_SAS_TOKEN
ARG AV_STORAGE_FOLDER

ENV INPUT_URL $AV_INPUT_URL
ENV PERIOD $AV_PERIOD
ENV STORAGE_URL $AV_STORAGE_URL
ENV STORAGE_SAS_TOKEN $AV_STORAGE_SAS_TOKEN
ENV STORAGE_FOLDER $AV_STORAGE_FOLDER


RUN apt-get -y update \
 && apt-get -y install ffmpeg wget lsof bc

RUN wget https://aka.ms/downloadazcopy-v10-linux
RUN tar -xvf downloadazcopy-v10-linux

RUN cp ./azcopy_linux_amd64_*/azcopy /usr/bin/
RUN chmod 755 /usr/bin/azcopy

RUN rm -f downloadazcopy-v10-linux
RUN rm -rf ./azcopy_linux_amd64_*/

COPY docker-entrypoint.sh /
RUN chmod 0755 /docker-entrypoint.sh 

CMD /docker-entrypoint.sh
