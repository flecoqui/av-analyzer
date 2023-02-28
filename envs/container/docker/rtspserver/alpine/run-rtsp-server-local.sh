#!/bin/bash
set -e
BASH_SCRIPT=`readlink -f "$0"`
BASH_DIR=`dirname "$BASH_SCRIPT"`
pushd "$BASH_DIR"  > /dev/null

export APP_VERSION=$(date +"%y%m%d.%H%M%S")
export RTSPSERVER_NAME="rtspserver"
export IMAGE_FOLDER="analyzer"
export FLAVOR="alpine"
export IMAGE_NAME="${RTSPSERVER_NAME}-${FLAVOR}-image"
export IMAGE_TAG=${APP_VERSION}
export CONTAINER_NAME="${RTSPSERVER_NAME}-container"
export ALTERNATIVE_TAG="latest"
export ARG_RTSP_SERVER_PORT_RTSP=554

echo "APP_VERSION $APP_VERSION"
echo "IMAGE_NAME $IMAGE_NAME"
echo "IMAGE_TAG $IMAGE_TAG"
echo "ALTERNATIVE_TAG $ALTERNATIVE_TAG"
echo "ARG_RTSP_SERVER_PORT_RTSP $ARG_RTSP_SERVER_PORT_RTSP"

mkdir -p ./input
cp ./../../../../../content/input/*.mp4 ./input
cmd="docker build  -f Dockerfile --build-arg ARG_RTSP_SERVER_PORT_RTSP=${ARG_RTSP_SERVER_PORT_RTSP} -t ${IMAGE_FOLDER}/${IMAGE_NAME}:${IMAGE_TAG} . " 
echo "$cmd"
eval "$cmd"
    
cmd="docker tag ${IMAGE_FOLDER}/${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_FOLDER}/${IMAGE_NAME}:${ALTERNATIVE_TAG}"
echo "$cmd"
eval "$cmd"

docker stop ${CONTAINER_NAME} 2>/dev/null || true
cmd="docker run  -d -it --rm --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 \
 -e PORT_RTSP=${ARG_RTSP_SERVER_PORT_RTSP}  -p ${ARG_RTSP_SERVER_PORT_RTSP}:${ARG_RTSP_SERVER_PORT_RTSP}/tcp \
 --name ${CONTAINER_NAME} ${IMAGE_FOLDER}/${IMAGE_NAME}:${ALTERNATIVE_TAG}" 
echo "$cmd"
eval "$cmd"

CONTAINER_RTSPSERVER_IP=$(docker container inspect "${CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
for i in ./input/*.mp4 
do 
echo "Run the following command from a local container:"
echo "  ffprobe -i rtsp://${CONTAINER_RTSPSERVER_IP}:${ARG_RTSP_SERVER_PORT_RTSP}/media/$(basename $i)"
echo "Run the following command from the host:"
echo "  ffprobe -i rtsp://127.0.0.1:${ARG_RTSP_SERVER_PORT_RTSP}/media/$(basename $i)"
done
# Remove temporary folder with mp4 files
rm ./input/*.mp4 > /dev/null
rmdir ./input > /dev/null
popd  > /dev/null