ARG AV_INPUT_URL=""
ARG AV_PERIOD=25
ARG AV_STORAGE_URL=""
ARG AV_STORAGE_SAS_TOKEN=""
ARG AV_STORAGE_FOLDER=""
ARG AV_EDGE_MODEL_URL=""
ARG AV_WAIT_START_FRAME="0"
ARG AV_WAIT_KEY_FRAME="0"


FROM        ubuntu:20.04 AS base

WORKDIR     /tmp/workdir

RUN     apt-get -yqq update && \
        apt-get install -yq --no-install-recommends ca-certificates expat libgomp1 && \
        apt-get autoremove -y && \
        apt-get clean -y

FROM base as build

ENV         FFMPEG_VERSION=5.1.2 \
    SRC=/usr/local

ARG AV_INPUT_URL 
ARG AV_PERIOD
ARG AV_STORAGE_URL
ARG AV_STORAGE_SAS_TOKEN
ARG AV_STORAGE_FOLDER
ARG AV_EDGE_MODEL_URL
ARG AV_WAIT_START_FRAME
ARG AV_WAIT_KEY_FRAME

ENV INPUT_URL $AV_INPUT_URL
ENV PERIOD $AV_PERIOD
ENV STORAGE_URL $AV_STORAGE_URL
ENV STORAGE_SAS_TOKEN $AV_STORAGE_SAS_TOKEN
ENV STORAGE_FOLDER $AV_STORAGE_FOLDER
ENV MODEL_URL $AV_EDGE_MODEL_URL
ENV WAIT_START_FRAME=$AV_WAIT_START_FRAME
ENV WAIT_KEY_FRAME=$AV_WAIT_KEY_FRAME

ARG         LD_LIBRARY_PATH=/opt/ffmpeg/lib
ARG         MAKEFLAGS="-j2"
ARG         PKG_CONFIG_PATH="/opt/ffmpeg/share/pkgconfig:/opt/ffmpeg/lib/pkgconfig:/opt/ffmpeg/lib64/pkgconfig"
ARG         PREFIX=/opt/ffmpeg
ARG         LD_LIBRARY_PATH="/opt/ffmpeg/lib:/opt/ffmpeg/lib64"


ARG DEBIAN_FRONTEND=noninteractive

RUN      buildDeps="autoconf \
                    automake \
                    cmake \
                    curl \
                    bzip2 \
                    libexpat1-dev \
                    g++ \
                    gcc \
                    git \
                    gperf \
                    libtool \
                    make \
                    meson \
                    nasm \
                    perl \
                    pkg-config \
                    python \
                    libssl-dev \
                    yasm \
                    libva-dev \
                    zlib1g-dev" && \
        apt-get -yqq update && \
        apt-get install -yq --no-install-recommends ${buildDeps}

## Download ffmpeg https://ffmpeg.org/
RUN  \
        DIR=/tmp/ffmpeg && mkdir -p ${DIR} && cd ${DIR} && \
        curl -sLO https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
        tar -jx --strip-components=1 -f ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
        ./configure     --disable-debug  --disable-doc    --disable-ffplay   --enable-shared --enable-gpl  --extra-libs=-ldl && \
        make ;  make install



## Build ffmpeg https://ffmpeg.org/
RUN  \
        DIR=/tmp/ffmpeg && cd ${DIR} && \
        ./configure \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --enable-gpl \
        --enable-nonfree \
        --enable-openssl \
        --enable-postproc \
        --enable-shared \
        --enable-small \
       --enable-vaapi \
        --enable-version3 \
        --extra-cflags="-I${PREFIX}/include" \
        --extra-ldflags="-L${PREFIX}/lib" \
        --extra-libs=-ldl \
        --extra-libs=-lpthread \
        --prefix="${PREFIX}" && \
        make clean && \
        make && \
        make install && \
        make distclean && \
        hash -r && \
        cd tools && \
        make qt-faststart && cp qt-faststart ${PREFIX}/bin/



## cleanup
RUN \
        ldd ${PREFIX}/bin/ffmpeg | grep opt/ffmpeg | cut -d ' ' -f 3 | xargs -i cp {} /usr/local/lib/ && \
        for lib in /usr/local/lib/*.so.*; do rm "${lib%%.so.*}".so || true;  ln -s "${lib##*/}" "${lib%%.so.*}".so; done && \
        cp ${PREFIX}/bin/* /usr/local/bin/ && \
        cp -r ${PREFIX}/share/ffmpeg /usr/local/share/ && \
        LD_LIBRARY_PATH=/usr/local/lib ffmpeg -buildconf && \
        cp -r ${PREFIX}/include/libav* ${PREFIX}/include/libpostproc ${PREFIX}/include/libsw* /usr/local/include && \
        mkdir -p /usr/local/lib/pkgconfig && \
        for pc in ${PREFIX}/lib/pkgconfig/libav*.pc ${PREFIX}/lib/pkgconfig/libpostproc.pc ${PREFIX}/lib/pkgconfig/libsw*.pc; do \
          sed "s:${PREFIX}:/usr/local:g" <"$pc" >/usr/local/lib/pkgconfig/"${pc##*/}"; \
        done

## flecoqui
COPY extractframe.c /tmp/ffmpeg

RUN \
        DIR=/tmp/ffmpeg && cd ${DIR} && \
        SOURCE_DIR=/tmp/ffmpeg && \
        BUILD_DIR=/opt/ffmpeg && \
        PKG_CONFIG_PATH="${PREFIX}" && ./configure --prefix="${PREFIX}" --pkg-config-flags="--static" --extra-cflags="-I${PREFIX}/include" --extra-ldflags="-L${PREFIX}/lib" --bindir="${PREFIX}/bin" --enable-gpl --enable-nonfree && \
        PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig/" && gcc -I${SOURCE_DIR}/ extractframe.c -o extractframe `pkg-config --cflags --libs libavformat libavcodec libavutil libswscale`   -lva-drm && \
        cp ${DIR}/extractframe /usr/local/bin


FROM        base AS release
ARG AV_INPUT_URL 
ARG AV_PERIOD
ARG AV_STORAGE_URL
ARG AV_STORAGE_SAS_TOKEN
ARG AV_STORAGE_FOLDER
ARG AV_EDGE_MODEL_URL
ARG AV_WAIT_START_FRAME
ARG AV_WAIT_KEY_FRAME

ENV INPUT_URL $AV_INPUT_URL
ENV PERIOD $AV_PERIOD
ENV STORAGE_URL $AV_STORAGE_URL
ENV STORAGE_SAS_TOKEN $AV_STORAGE_SAS_TOKEN
ENV STORAGE_FOLDER $AV_STORAGE_FOLDER
ENV MODEL_URL $AV_EDGE_MODEL_URL
ENV WAIT_START_FRAME=$AV_WAIT_START_FRAME
ENV WAIT_KEY_FRAME=$AV_WAIT_KEY_FRAME


ENV         LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64

COPY --from=build /usr/local /usr/local/

RUN apt-get update -y && \
	apt-get install -y --no-install-recommends libva-drm2 libva2 i965-va-driver && \
	rm -rf /var/lib/apt/lists/*

RUN apt-get -y update \
 && apt-get -y install ffmpeg wget lsof curl bc

RUN wget https://aka.ms/downloadazcopy-v10-linux
RUN tar -xvf downloadazcopy-v10-linux

RUN cp ./azcopy_linux_amd64_*/azcopy /usr/bin/
RUN chmod 755 /usr/bin/azcopy

RUN rm -f downloadazcopy-v10-linux
RUN rm -rf ./azcopy_linux_amd64_*/

COPY docker-entrypoint.sh /
RUN chmod 0755 /docker-entrypoint.sh 

CMD /docker-entrypoint.sh

