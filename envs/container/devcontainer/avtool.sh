#!/bin/bash
##########################################################################################################################################################################################
#- Purpose: Script used to install pre-requisites, deploy/undeploy service, start/stop service, test service
#- Parameters are:
#- [-a] action - value: login, build, deploy, undeploy, start, stop, status
#- [-c] configuration file - which contains the list of path of each avtool.sh to call (avtool.env by default)
#
# executable
###########################################################################################################################################################################################
set -u
BASH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$BASH_DIR"
#######################################################
#- function used to print out script usage
#######################################################
function usage() {
    echo
    echo "Arguments:"
    echo -e " -a  Sets AV Tool action {build, deploy, undeploy, start, stop, status}"
    echo -e " -c  Sets the AV Tool configuration file"
    echo
    echo "Example:"
    echo -e " bash ./avtool.sh -a build "
    echo -e " bash ./avtool.sh -a deploy "
    
}
action=
configuration_file=${BASH_DIR}/../../../config/.avtoolconfig
while getopts "a:c:hq" opt; do
    case $opt in
    a) action=$OPTARG ;;
    c) configuration_file=$OPTARG ;;    
    :)
        echo "Error: -${OPTARG} requires a value"
        exit 1
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

# Validation
if [[ $# -eq 0 || -z $action || -z $configuration_file ]]; then
    echo "Required parameters are missing"
    usage
    exit 1
fi
if [[ ! $action == login && ! $action == build && ! $action == start && ! $action == stop && ! $action == status && ! $action == deploy && ! $action == undeploy ]]; then
    echo "Required action is missing, values: login, build, deploy, undeploy, start, stop, status"
    usage
    exit 1
fi

AV_TEMPDIR=/tmp/test
AV_FLAVOR=ubuntu
AV_IMAGE_FOLDER=av-services

AV_RTMP_RTSP_CONTAINER_NAME=rtmprtspsink-${AV_FLAVOR}-container
AV_RTMP_RTSP_IMAGE_NAME=rtmprtspsink-${AV_FLAVOR}-image 
AV_RTMP_RTSP_COMPANYNAME=contoso
AV_RTMP_RTSP_HOSTNAME=localhost
AV_RTMP_RTSP_PORT_HLS=8080
AV_RTMP_RTSP_PORT_HTTP=80
AV_RTMP_RTSP_PORT_SSL=443
AV_RTMP_RTSP_PORT_RTMP=1935
AV_RTMP_RTSP_PORT_RTSP=8554
AV_RTMP_RTSP_STREAM_LIST=camera1:camera2

AV_MODEL_YOLO_ONNX_PORT_HTTP=8081
AV_MODEL_YOLO_ONNX_IMAGE_NAME=http-yolov3-onnx-image
AV_MODEL_YOLO_ONNX_CONTAINER_NAME=http-yolov3-onnx-container

AV_MODEL_COMPUTER_VISION_PORT_HTTP=8082
AV_MODEL_COMPUTER_VISION_IMAGE_NAME=custom-vision-image
AV_MODEL_COMPUTER_VISION_CONTAINER_NAME=custom-vision-container
AV_MODEL_COMPUTER_VISION_URL=""
AV_MODEL_COMPUTER_VISION_KEY=""

AV_MODEL_CUSTOM_VISION_PORT_HTTP=8083
AV_MODEL_CUSTOM_VISION_IMAGE_NAME=custom-vision-image
AV_MODEL_CUSTOM_VISION_CONTAINER_NAME=custom-vision-container
AV_MODEL_CUSTOM_VISION_URL=""
AV_MODEL_CUSTOM_VISION_KEY=""

AV_FFMPEG_IMAGE_NAME=ffmpeg-image
AV_FFMPEG_CONTAINER_NAME=ffmpeg-container
AV_FFMPEG_LOCAL_FILE=camera-300s.mkv
AV_FFMPEG_VOLUME=/tempvol
AV_FFMPEG_STREAM_LIST=camera1:camera2
AV_FFMPEG_FILE_LIST=camera-300s.mkv:lots_015.mkv

AV_RECORDER_IMAGE_NAME=recorder-image
AV_RECORDER_CONTAINER_NAME=recorder-container
AV_RECORDER_INPUT_URL=""
AV_RECORDER_PERIOD=2
AV_RECORDER_STORAGE_URL="https://to_be_completed.blob.core.windows.net/to_be_completed"
AV_RECORDER_STORAGE_SAS_TOKEN="?to_be_completed"
AV_RECORDER_STORAGE_FOLDER=/to_be_completed
AV_RECORDER_VOLUME=/tempvol
AV_RECORDER_STREAM_LIST=camera1:camera2

AV_EDGE_IMAGE_NAME=edge-image
AV_EDGE_CONTAINER_NAME=edge-container
AV_EDGE_INPUT_URL=""
AV_EDGE_PERIOD=25
AV_EDGE_STORAGE_URL="https://to_be_completed.blob.core.windows.net/to_be_completed"
AV_EDGE_STORAGE_SAS_TOKEN="?to_be_completed"
AV_EDGE_STORAGE_FOLDER=/to_be_completed
AV_EDGE_MODEL_URL=""
AV_EDGE_VOLUME=/tempvol
AV_EDGE_STREAM_LIST=camera1:camera2

AV_WEBAPP_IMAGE_NAME=webapp-image
AV_WEBAPP_CONTAINER_NAME=webapp-container
AV_WEBAPP_PORT_HTTP=8084
AV_WEBAPP_STORAGE_RESULT_URL="https://to_be_completed.blob.core.windows.net/to_be_completed"
AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN="?to_be_completed"
AV_WEBAPP_STORAGE_RECORD_URL="https://to_be_completed.blob.core.windows.net/to_be_completed"
AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN="?to_be_completed"
AV_WEBAPP_FOLDER=version1.0
AV_WEBAPP_STREAM_LIST=camera1:camera2
AV_WEBAPP_STREAM_URL_PREFIX=""

AV_RTSP_SOURCE_IMAGE_NAME=rtsp-source-image
AV_RTSP_SOURCE_CONTAINER_NAME=rtsp-source-container
AV_RTSP_SOURCE_PORT=554

# Check if configuration file exists
if [[ ! -f "$configuration_file" ]]; then
    cat > "$configuration_file" << EOF
AV_TEMPDIR=${AV_TEMPDIR}
AV_FLAVOR=${AV_FLAVOR}
AV_IMAGE_FOLDER=${AV_IMAGE_FOLDER}

AV_RTMP_RTSP_CONTAINER_NAME=${AV_RTMP_RTSP_CONTAINER_NAME}
AV_RTMP_RTSP_IMAGE_NAME=${AV_RTMP_RTSP_IMAGE_NAME} 
AV_RTMP_RTSP_COMPANYNAME=${AV_RTMP_RTSP_COMPANYNAME}
AV_RTMP_RTSP_HOSTNAME=${AV_RTMP_RTSP_HOSTNAME}
AV_RTMP_RTSP_PORT_HLS=${AV_RTMP_RTSP_PORT_HLS}
AV_RTMP_RTSP_PORT_HTTP=${AV_RTMP_RTSP_PORT_HTTP}
AV_RTMP_RTSP_PORT_SSL=${AV_RTMP_RTSP_PORT_SSL}
AV_RTMP_RTSP_PORT_RTMP=${AV_RTMP_RTSP_PORT_RTMP}
AV_RTMP_RTSP_PORT_RTSP=${AV_RTMP_RTSP_PORT_RTSP}
AV_RTMP_RTSP_STREAM_LIST=${AV_RTMP_RTSP_STREAM_LIST}

AV_MODEL_YOLO_ONNX_PORT_HTTP=${AV_MODEL_YOLO_ONNX_PORT_HTTP}
AV_MODEL_YOLO_ONNX_IMAGE_NAME=${AV_MODEL_YOLO_ONNX_IMAGE_NAME}
AV_MODEL_YOLO_ONNX_CONTAINER_NAME=${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}

AV_MODEL_COMPUTER_VISION_PORT_HTTP=${AV_MODEL_COMPUTER_VISION_PORT_HTTP}
AV_MODEL_COMPUTER_VISION_IMAGE_NAME=${AV_MODEL_COMPUTER_VISION_IMAGE_NAME}
AV_MODEL_COMPUTER_VISION_CONTAINER_NAME=${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}
AV_MODEL_COMPUTER_VISION_URL=${AV_MODEL_COMPUTER_VISION_URL}
AV_MODEL_COMPUTER_VISION_KEY=${AV_MODEL_COMPUTER_VISION_KEY}

AV_MODEL_CUSTOM_VISION_PORT_HTTP=${AV_MODEL_CUSTOM_VISION_PORT_HTTP}
AV_MODEL_CUSTOM_VISION_IMAGE_NAME=${AV_MODEL_CUSTOM_VISION_IMAGE_NAME}
AV_MODEL_CUSTOM_VISION_CONTAINER_NAME=${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}
AV_MODEL_CUSTOM_VISION_URL=${AV_MODEL_CUSTOM_VISION_URL}
AV_MODEL_CUSTOM_VISION_KEY=${AV_MODEL_CUSTOM_VISION_KEY}

AV_FFMPEG_IMAGE_NAME=${AV_FFMPEG_IMAGE_NAME}
AV_FFMPEG_CONTAINER_NAME=${AV_FFMPEG_CONTAINER_NAME}
AV_FFMPEG_LOCAL_FILE=${AV_FFMPEG_LOCAL_FILE}
AV_FFMPEG_VOLUME=${AV_FFMPEG_VOLUME}
AV_FFMPEG_STREAM_LIST=${AV_FFMPEG_STREAM_LIST}
AV_FFMPEG_FILE_LIST=${AV_FFMPEG_FILE_LIST}

AV_RECORDER_IMAGE_NAME=${AV_RECORDER_IMAGE_NAME}
AV_RECORDER_CONTAINER_NAME=${AV_RECORDER_CONTAINER_NAME}
AV_RECORDER_INPUT_URL=${AV_RECORDER_INPUT_URL}
AV_RECORDER_PERIOD=${AV_RECORDER_PERIOD}
AV_RECORDER_STORAGE_URL=${AV_RECORDER_STORAGE_URL}
AV_RECORDER_STORAGE_SAS_TOKEN=${AV_RECORDER_STORAGE_SAS_TOKEN}
AV_RECORDER_STORAGE_FOLDER=${AV_RECORDER_STORAGE_FOLDER}
AV_RECORDER_VOLUME=${AV_RECORDER_VOLUME}
AV_RECORDER_STREAM_LIST=${AV_RECORDER_STREAM_LIST}

AV_EDGE_IMAGE_NAME=${AV_EDGE_IMAGE_NAME}
AV_EDGE_CONTAINER_NAME=${AV_EDGE_CONTAINER_NAME}
AV_EDGE_INPUT_URL=${AV_EDGE_INPUT_URL}
AV_EDGE_PERIOD=${AV_EDGE_PERIOD}
AV_EDGE_STORAGE_URL=${AV_EDGE_STORAGE_URL}
AV_EDGE_STORAGE_SAS_TOKEN=${AV_EDGE_STORAGE_SAS_TOKEN}
AV_EDGE_STORAGE_FOLDER=${AV_EDGE_STORAGE_FOLDER}
AV_EDGE_MODEL_URL=${AV_EDGE_MODEL_URL}
AV_EDGE_VOLUME=${AV_EDGE_VOLUME}
AV_EDGE_STREAM_LIST=${AV_EDGE_STREAM_LIST}

AV_WEBAPP_IMAGE_NAME=${AV_WEBAPP_IMAGE_NAME}
AV_WEBAPP_CONTAINER_NAME=${AV_WEBAPP_CONTAINER_NAME}
AV_WEBAPP_PORT_HTTP=${AV_WEBAPP_PORT_HTTP}
AV_WEBAPP_STORAGE_RESULT_URL=${AV_WEBAPP_STORAGE_RESULT_URL}
AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN=${AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN}
AV_WEBAPP_STORAGE_RECORD_URL=${AV_WEBAPP_STORAGE_RECORD_URL}
AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN=${AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN}
AV_WEBAPP_FOLDER=${AV_WEBAPP_FOLDER}
AV_WEBAPP_STREAM_LIST=${AV_WEBAPP_STREAM_LIST}
AV_WEBAPP_STREAM_URL_PREFIX=${AV_WEBAPP_STREAM_URL_PREFIX}

AV_RTSP_SOURCE_IMAGE_NAME=${AV_RTSP_SOURCE_IMAGE_NAME}
AV_RTSP_SOURCE_CONTAINER_NAME=${AV_RTSP_SOURCE_CONTAINER_NAME}
AV_RTSP_SOURCE_PORT=${AV_RTSP_SOURCE_PORT}
EOF
fi
# Read variables in configuration file
export $(grep AV_TEMPDIR "$configuration_file")
export $(grep AV_FLAVOR "$configuration_file")
export $(grep AV_IMAGE_FOLDER "$configuration_file")

export $(grep AV_RTMP_RTSP_CONTAINER_NAME "$configuration_file")
export $(grep AV_RTMP_RTSP_IMAGE_NAME "$configuration_file") 
export $(grep AV_RTMP_RTSP_COMPANYNAME "$configuration_file")
export $(grep AV_RTMP_RTSP_HOSTNAME "$configuration_file")
export $(grep AV_RTMP_RTSP_PORT_HLS "$configuration_file")
export $(grep AV_RTMP_RTSP_PORT_HTTP "$configuration_file")
export $(grep AV_RTMP_RTSP_PORT_SSL "$configuration_file")
export $(grep AV_RTMP_RTSP_PORT_RTMP "$configuration_file")
export $(grep AV_RTMP_RTSP_PORT_RTSP "$configuration_file")
export $(grep AV_RTMP_RTSP_STREAM_LIST "$configuration_file")

export $(grep AV_MODEL_YOLO_ONNX_PORT_HTTP "$configuration_file")
export $(grep AV_MODEL_YOLO_ONNX_IMAGE_NAME "$configuration_file")
export $(grep AV_MODEL_YOLO_ONNX_CONTAINER_NAME "$configuration_file")

export $(grep AV_MODEL_COMPUTER_VISION_PORT_HTTP "$configuration_file")
export $(grep AV_MODEL_COMPUTER_VISION_IMAGE_NAME "$configuration_file")
export $(grep AV_MODEL_COMPUTER_VISION_CONTAINER_NAME "$configuration_file")
export $(grep AV_MODEL_COMPUTER_VISION_URL "$configuration_file")
export $(grep AV_MODEL_COMPUTER_VISION_KEY "$configuration_file")

export $(grep AV_MODEL_CUSTOM_VISION_PORT_HTTP "$configuration_file")
export $(grep AV_MODEL_CUSTOM_VISION_IMAGE_NAME "$configuration_file")
export $(grep AV_MODEL_CUSTOM_VISION_CONTAINER_NAME "$configuration_file")
export $(grep AV_MODEL_CUSTOM_VISION_URL "$configuration_file")
export $(grep AV_MODEL_CUSTOM_VISION_KEY "$configuration_file")

export $(grep AV_FFMPEG_IMAGE_NAME "$configuration_file")
export $(grep AV_FFMPEG_CONTAINER_NAME "$configuration_file")
export $(grep AV_FFMPEG_LOCAL_FILE "$configuration_file")
export $(grep AV_FFMPEG_VOLUME "$configuration_file")
export $(grep AV_FFMPEG_STREAM_LIST "$configuration_file")
export $(grep AV_FFMPEG_FILE_LIST "$configuration_file")

export $(grep AV_RECORDER_IMAGE_NAME "$configuration_file")
export $(grep AV_RECORDER_CONTAINER_NAME "$configuration_file")
export $(grep AV_RECORDER_INPUT_URL "$configuration_file")
export $(grep AV_RECORDER_PERIOD "$configuration_file")
export $(grep AV_RECORDER_STORAGE_URL "$configuration_file")
export $(grep AV_RECORDER_STORAGE_SAS_TOKEN "$configuration_file")
export $(grep AV_RECORDER_STORAGE_FOLDER "$configuration_file")
export $(grep AV_RECORDER_VOLUME "$configuration_file")
export $(grep AV_RECORDER_STREAM_LIST "$configuration_file")


export $(grep AV_EDGE_IMAGE_NAME "$configuration_file")
export $(grep AV_EDGE_CONTAINER_NAME "$configuration_file")
export $(grep AV_EDGE_INPUT_URL "$configuration_file")
export $(grep AV_EDGE_PERIOD "$configuration_file")
export $(grep AV_EDGE_STORAGE_URL "$configuration_file")
export $(grep AV_EDGE_STORAGE_SAS_TOKEN "$configuration_file")
export $(grep AV_EDGE_STORAGE_FOLDER "$configuration_file")
export $(grep AV_EDGE_MODEL_URL "$configuration_file")
export $(grep AV_EDGE_VOLUME "$configuration_file")
export $(grep AV_EDGE_STREAM_LIST "$configuration_file")

export $(grep AV_WEBAPP_IMAGE_NAME "$configuration_file")
export $(grep AV_WEBAPP_CONTAINER_NAME "$configuration_file")
export $(grep AV_WEBAPP_PORT_HTTP "$configuration_file")
export $(grep AV_WEBAPP_STORAGE_RESULT_URL "$configuration_file")
export $(grep AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN "$configuration_file")
export $(grep AV_WEBAPP_STORAGE_RECORD_URL "$configuration_file")
export $(grep AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN "$configuration_file")
export $(grep AV_WEBAPP_FOLDER "$configuration_file")
export $(grep AV_WEBAPP_STREAM_LIST "$configuration_file")
export $(grep AV_WEBAPP_STREAM_URL_PREFIX "$configuration_file")

export $(grep AV_RTSP_SOURCE_IMAGE_NAME "$configuration_file")
export $(grep AV_RTSP_SOURCE_CONTAINER_NAME "$configuration_file")
export $(grep AV_RTSP_SOURCE_PORT "$configuration_file")

# colors for formatting the ouput
GREEN='\033[1;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


checkError() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}\nAn error occured exiting from the current bash${NC}"
        exit 1
    fi
}
checkDevContainerMode () {
    checkDevContainerModeResult="0"
    if [[ -f /avworkspace/.devcontainer/devcontainer.json ]]; 
    then
        checkDevContainerModeResult="1"
    fi
    echo $checkDevContainerModeResult
    return
}
# Create temporary directory
if [[ ! -d "${AV_TEMPDIR}" ]] ; then
    mkdir "${AV_TEMPDIR}"
fi


if [[ "${action}" == "login" ]] ; then
    echo "Login..."
    docker login
    echo -e "${GREEN}Login done${NC}"
    exit 0
fi

if [[ "${action}" == "build" ]] ; then
    echo "Building containers"
    echo "Building container $AV_RTMP_RTSP_CONTAINER_NAME..."
    docker container stop ${AV_RTMP_RTSP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_RTMP_RTSP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    cmd="docker build  --build-arg  AV_RTMP_RTSP_PORT_RTSP=${AV_RTMP_RTSP_PORT_RTSP} --build-arg  AV_RTMP_RTSP_PORT_RTMP=${AV_RTMP_RTSP_PORT_RTMP} --build-arg  AV_RTMP_RTSP_PORT_SSL=${AV_RTMP_RTSP_PORT_SSL} --build-arg  AV_RTMP_RTSP_PORT_HTTP=${AV_RTMP_RTSP_PORT_HTTP} --build-arg  AV_RTMP_RTSP_PORT_HLS=${AV_RTMP_RTSP_PORT_HLS}  --build-arg  AV_RTMP_RTSP_HOSTNAME=${AV_RTMP_RTSP_HOSTNAME} --build-arg  AV_RTMP_RTSP_COMPANYNAME=${AV_RTMP_RTSP_COMPANYNAME} --build-arg  AV_RTMP_RTSP_STREAM_LIST=${AV_RTMP_RTSP_STREAM_LIST} -t ${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME} ${BASH_DIR}/../docker/rtmprtspsink/ubuntu/." 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Building container $AV_RTMP_RTSP_CONTAINER_NAME done..."

    echo "Building container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    docker container stop ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    cmd="docker build -f ${BASH_DIR}/../docker/yolov3/http-cpu/yolov3.dockerfile ${BASH_DIR}/../docker/yolov3/http-cpu/. -t ${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Building container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done..."

    echo "Building container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    docker container stop ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    cmd="docker build --build-arg  AV_MODEL_COMPUTER_VISION_PORT_HTTP=${AV_MODEL_COMPUTER_VISION_PORT_HTTP} -f ${BASH_DIR}/../docker/computervision/http-cpu/Dockerfile ${BASH_DIR}/../docker/computervision/http-cpu/. -t ${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Building container $AV_MODEL_COMPUTER_VISION_PORT_HTTP done..."

    echo "Building container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    docker container stop ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    cmd="docker build --build-arg  AV_MODEL_CUSTOM_VISION_PORT_HTTP=${AV_MODEL_CUSTOM_VISION_PORT_HTTP} -f ${BASH_DIR}/../docker/customvision/http-cpu/Dockerfile ${BASH_DIR}/../docker/customvision/http-cpu/. -t ${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Building container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done..."

    echo "Building container $AV_FFMPEG_CONTAINER_NAME..."
    streamArray=(${AV_FFMPEG_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        docker container stop "${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}" > /dev/null 2> /dev/null  || true
        docker container rm "${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}" > /dev/null 2> /dev/null  || true
    done    
    docker image rm ${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    cmd="docker build   -f ${BASH_DIR}/../docker/ffmpeg/ubuntu/Dockerfile ${BASH_DIR}/../docker/ffmpeg/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Building container $AV_FFMPEG_CONTAINER_NAME done..."

    echo "Building container $AV_RECORDER_CONTAINER_NAME..."
    streamArray=(${AV_RECORDER_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        docker container stop "${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]}" > /dev/null 2> /dev/null  || true
        docker container rm "${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]}" > /dev/null 2> /dev/null  || true
    done    
    docker image rm ${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME} > /dev/null 2> /dev/null  || true    
    cmd="docker build   -f ${BASH_DIR}/../docker/recorder/ubuntu/Dockerfile ${BASH_DIR}/../docker/recorder/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Building container $AV_RECORDER_CONTAINER_NAME done..."

    echo "Building container $AV_EDGE_CONTAINER_NAME..."
    streamArray=(${AV_EDGE_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        docker container stop "${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}" > /dev/null 2> /dev/null  || true
        docker container rm "${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}" > /dev/null 2> /dev/null  || true
    done    
    docker image rm ${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    cmd="docker build   -f ${BASH_DIR}/../docker/avedge/ubuntu/Dockerfile ${BASH_DIR}/../docker/avedge/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Building container $AV_EDGE_CONTAINER_NAME done..."

    echo "Building container $AV_WEBAPP_CONTAINER_NAME..."
    docker container stop ${AV_WEBAPP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_WEBAPP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME} > /dev/null 2> /dev/null  || true

    pushd ${BASH_DIR}/../docker/webapp/ubuntu
    echo "Updating Web App configuration"
    # container version (current date)
    export APP_VERSION=$(date +"%y%m%d.%H%M%S")

    cmd="cat ./src/config.json  | jq -r '.version = \"${APP_VERSION}\"' > tmp.$$.json && mv tmp.$$.json ./src/config.json"
    eval "$cmd"    
    cmd="cat ./src/config.json  | jq -r '.storageAccountResultUrl = \"${AV_WEBAPP_STORAGE_RESULT_URL}\"' > tmp.$$.json && mv tmp.$$.json ./src/config.json"
    eval "$cmd"    
    cmd="cat ./src/config.json  | jq -r '.storageAccountResultSASToken = \"${AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN}\"' > tmp.$$.json && mv tmp.$$.json ./src/config.json"
    eval "$cmd"    
    cmd="cat ./src/config.json  | jq -r '.storageAccountRecordUrl = \"${AV_WEBAPP_STORAGE_RECORD_URL}\"' > tmp.$$.json && mv tmp.$$.json ./src/config.json"
    eval "$cmd"    
    cmd="cat ./src/config.json  | jq -r '.storageAccountRecordSASToken = \"${AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN}\"' > tmp.$$.json && mv tmp.$$.json ./src/config.json"
    eval "$cmd"    
    cmd="cat ./src/config.json  | jq -r '.storageFolder = \"${AV_WEBAPP_FOLDER}\"' > tmp.$$.json && mv tmp.$$.json ./src/config.json"
    eval "$cmd"    
    cmd="cat ./src/config.json  | jq -r '.cameraList = \"${AV_WEBAPP_STREAM_LIST}\"' > tmp.$$.json && mv tmp.$$.json ./src/config.json"
    eval "$cmd"  
    cmd="cat ./src/config.json  | jq -r '.cameraUrlPrefix = \"${AV_WEBAPP_STREAM_URL_PREFIX}\"' > tmp.$$.json && mv tmp.$$.json ./src/config.json"
    eval "$cmd"        

    echo "Building the Web App Application"
    npm install
    npm audit fix
    tsc --build tsconfig.json
    webpack --config webpack.config.js
    popd

    echo "Building the Web App Container"
    cmd="docker build   -f ${BASH_DIR}/../docker/webapp/ubuntu/Dockerfile ${BASH_DIR}/../docker/webapp/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Building container $AV_WEBAPP_CONTAINER_NAME done..."

    echo "Building container $AV_RTSP_SOURCE_CONTAINER_NAME..."
    docker container stop ${AV_RTSP_SOURCE_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_RTSP_SOURCE_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    cp ${BASH_DIR}/../../../content/camera-300s.mkv ${BASH_DIR}/../docker/rtspsource
    cmd="docker build  -f ${BASH_DIR}/../docker/rtspsource/Dockerfile ${BASH_DIR}/../docker/rtspsource/. -t ${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    rm ${BASH_DIR}/../docker/rtspsource/camera-300s.mkv
    echo "Building container $AV_RTSP_SOURCE_CONTAINER_NAME done..."

    echo -e "${GREEN}Building container done${NC}"
fi


if [[ "${action}" == "deploy" ]] ; then
    echo "Deploying containers..."

    echo "Copying Content file to shared volume..."
    fileArray=(${AV_FFMPEG_FILE_LIST//:/ })
    for i in "${!fileArray[@]}"
    do
        cp ${BASH_DIR}/../../../content/${fileArray[i]} /content
    done


    echo "Deploying and starting container $AV_RTMP_RTSP_CONTAINER_NAME..."
    cmd="docker run  -d -it   -p ${AV_RTMP_RTSP_PORT_HTTP}:${AV_RTMP_RTSP_PORT_HTTP}/tcp  -p ${AV_RTMP_RTSP_PORT_HLS}:${AV_RTMP_RTSP_PORT_HLS}/tcp    -p ${AV_RTMP_RTSP_PORT_RTMP}:${AV_RTMP_RTSP_PORT_RTMP}/tcp -p ${AV_RTMP_RTSP_PORT_RTSP}:${AV_RTMP_RTSP_PORT_RTSP}/tcp  -p ${AV_RTMP_RTSP_PORT_SSL}:${AV_RTMP_RTSP_PORT_SSL}/tcp -e PORT_RTSP=${AV_RTMP_RTSP_PORT_RTSP} -e PORT_RTMP=${AV_RTMP_RTSP_PORT_RTMP} -e PORT_SSL=${AV_RTMP_RTSP_PORT_SSL} -e PORT_HTTP=${AV_RTMP_RTSP_PORT_HTTP} -e PORT_HLS=${AV_RTMP_RTSP_PORT_HLS}  -e HOSTNAME=${AV_RTMP_RTSP_HOSTNAME} -e COMPANYNAME=${AV_RTMP_RTSP_COMPANYNAME} -e  STREAM_LIST=${AV_RTMP_RTSP_STREAM_LIST} --name ${AV_RTMP_RTSP_CONTAINER_NAME} ${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Deploying and starting container $AV_RTMP_RTSP_CONTAINER_NAME done"

    echo "Deploying and starting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    cmd="docker run   --name ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} -p ${AV_MODEL_YOLO_ONNX_PORT_HTTP}:${AV_MODEL_YOLO_ONNX_PORT_HTTP}/tcp -d  -i ${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME}"
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Deploying and starting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done"
    
    echo "Deploying and starting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    cmd="docker run   --name ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} -e COMPUTER_VISION_URL=${AV_MODEL_COMPUTER_VISION_URL} -e COMPUTER_VISION_KEY=${AV_MODEL_COMPUTER_VISION_KEY} -p ${AV_MODEL_COMPUTER_VISION_PORT_HTTP}:${AV_MODEL_COMPUTER_VISION_PORT_HTTP}/tcp -d  -i ${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME}"
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Deploying and starting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done"


    echo "Deploying and starting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    cmd="docker run   --name ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} -e CUSTOM_VISION_URL=${AV_MODEL_CUSTOM_VISION_URL} -e CUSTOM_VISION_KEY=${AV_MODEL_CUSTOM_VISION_KEY} -p ${AV_MODEL_CUSTOM_VISION_PORT_HTTP}:${AV_MODEL_CUSTOM_VISION_PORT_HTTP}/tcp -d  -i ${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME}"
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Deploying and starting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done"

    echo "Deploying and starting container(s) $AV_FFMPEG_CONTAINER_NAME..."
    if [[ $(checkDevContainerMode) == "1" ]] ; then
        docker network connect spikes_devcontainer_default ${AV_RTMP_RTSP_CONTAINER_NAME}  2> /dev/null || true  
        DEV_CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
        TEMPVOL="content-volume"   
    else
        CONTAINER_IP=${AV_RTMP_RTSP_HOSTNAME}
        TEMPVOL=${AV_TEMPDIR}   
    fi
    if [[ ${AV_FFMPEG_VOLUME::1} != "/" ]]
    then
        AV_FFMPEG_VOLUME="/${AV_FFMPEG_VOLUME}"
    fi
    echo "RTMP server IP Address: ${CONTAINER_RTMP_SERVER_IP}"
    echo "TEMPVOL: ${TEMPVOL}"    

    streamArray=(${AV_FFMPEG_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Deploying and starting container(s) ${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker run    -d -it -v ${TEMPVOL}:${AV_FFMPEG_VOLUME} --name \"${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}\" ${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME} ffmpeg -hide_banner -loglevel error  -re -stream_loop -1 -i ${AV_FFMPEG_VOLUME}/${fileArray[i]} -codec copy  -f flv rtmp://${CONTAINER_RTMP_SERVER_IP}:${AV_RTMP_RTSP_PORT_RTMP}/live/${streamArray[i]}"
        echo "$cmd"
        eval "$cmd"
        checkError
        echo "Deploying and starting container(s) ${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]} done..."
    done

    echo "Deploying and starting container(s) $AV_RECORDER_CONTAINER_NAME..."
    if [[ $(checkDevContainerMode) == "1" ]] ; then
        docker network connect spikes_devcontainer_default ${AV_RTMP_RTSP_CONTAINER_NAME}  2> /dev/null || true  
        DEV_CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
        TEMPVOL="content-volume"   
    else
        CONTAINER_IP=${AV_RTMP_RTSP_HOSTNAME}
        TEMPVOL=${AV_TEMPDIR}   
    fi    
    if [[ ${AV_RECORDER_VOLUME::1} != "/" ]]
    then
        AV_RECORDER_VOLUME="/${AV_RECORDER_VOLUME}"
    fi
    streamArray=(${AV_RECORDER_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Deploying and starting container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker run    -d -it -v ${TEMPVOL}:${AV_RECORDER_VOLUME} -e INPUT_URL=\"rtmp://${CONTAINER_RTMP_SERVER_IP}:${AV_RTMP_RTSP_PORT_RTMP}/live/${streamArray[i]}\" -e  PERIOD=\"${AV_RECORDER_PERIOD}\"  -e  STORAGE_URL=\"${AV_RECORDER_STORAGE_URL}\"   -e  STORAGE_SAS_TOKEN=\"${AV_RECORDER_STORAGE_SAS_TOKEN}\"  -e  STORAGE_FOLDER=\"${AV_RECORDER_STORAGE_FOLDER}/${streamArray[i]}\"   --name ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} ${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME} "
        echo "$cmd"
        eval "$cmd"
        checkError
        echo "Deploying and starting container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} done"
    done    
    echo "Deploying and starting container $AV_RECORDER_CONTAINER_NAME done"

    echo "Deploying and starting container(s) $AV_EDGE_CONTAINER_NAME..."
    if [[ $(checkDevContainerMode) == "1" ]] ; then
        docker network connect spikes_devcontainer_default ${AV_RTMP_RTSP_CONTAINER_NAME}  2> /dev/null || true  
        DEV_CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')

        docker network connect spikes_devcontainer_default ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}  2> /dev/null || true  
        DEV_CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
        CONTAINER_MODEL_PORT_HTTP=$AV_MODEL_YOLO_ONNX_PORT_HTTP
        #docker network connect spikes_devcontainer_default ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}  2> /dev/null || true  
        #DEV_CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        #CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
        #CONTAINER_MODEL_PORT_HTTP=$AV_MODEL_COMPUTER_VISION_PORT_HTTP

        #docker network connect spikes_devcontainer_default ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}  2> /dev/null || true  
        #DEV_CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        #CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
        #CONTAINER_MODEL_PORT_HTTP=$AV_MODEL_CUSTOM_VISION_PORT_HTTP
        TEMPVOL="content-volume"   
    else
        CONTAINER_IP=${AV_RTMP_RTSP_HOSTNAME}
        TEMPVOL=${AV_TEMPDIR}   
    fi    
    if [[ ${AV_EDGE_VOLUME::1} != "/" ]]
    then
        AV_EDGE_VOLUME="/${AV_EDGE_VOLUME}"
    fi
    streamArray=(${AV_EDGE_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Deploying and starting container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker run   -d -it -v ${TEMPVOL}:${AV_EDGE_VOLUME} -e MODEL_URL=\"http://${CONTAINER_MODEL_SERVER_IP}:${CONTAINER_MODEL_PORT_HTTP}/score\" -e INPUT_URL=\"rtmp://${CONTAINER_RTMP_SERVER_IP}:${AV_RTMP_RTSP_PORT_RTMP}/live/${streamArray[i]}\" -e  PERIOD=\"${AV_EDGE_PERIOD}\"  -e  STORAGE_URL=\"${AV_EDGE_STORAGE_URL}\"   -e  STORAGE_SAS_TOKEN=\"${AV_EDGE_STORAGE_SAS_TOKEN}\"  -e  STORAGE_FOLDER=\"${AV_EDGE_STORAGE_FOLDER}/${streamArray[i]}\"   --name \"${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}\" ${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME} "
        echo "$cmd"
        eval "$cmd"
        checkError
        echo "Deploying and starting container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} done"
    done  
    echo "Deploying and starting container(s) $AV_EDGE_CONTAINER_NAME done"

    echo "Deploying and starting container $AV_WEBAPP_CONTAINER_NAME..."
    cmd="docker run  -d -it   -p ${AV_WEBAPP_PORT_HTTP}:${AV_WEBAPP_PORT_HTTP}/tcp  -e WEBAPP_PORT_HTTP=${AV_WEBAPP_PORT_HTTP} -e  WEBAPP_STORAGE_RESULT_URL=\"${AV_WEBAPP_STORAGE_RESULT_URL}\"   -e  WEBAPP_STORAGE_RESULT_SAS_TOKEN=\"${AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN}\" -e  WEBAPP_STORAGE_RECORD_URL=\"${AV_WEBAPP_STORAGE_RECORD_URL}\"   -e  WEBAPP_STORAGE_RECORD_SAS_TOKEN=\"${AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN}\" -e WEBAPP_STREAM_URL_PREFIX=\"http://localhost:$AV_RTMP_RTSP_PORT_HLS/hls\" --name ${AV_WEBAPP_CONTAINER_NAME} ${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Deploying and starting container $AV_RTMP_RTSP_CONTAINER_NAME done"

    echo "Deploying and starting container $AV_RTSP_SOURCE_CONTAINER_NAME..."
    cmd="docker run  -d -it   -p ${AV_RTSP_SOURCE_PORT}:${AV_RTSP_SOURCE_PORT}  --name ${AV_RTSP_SOURCE_CONTAINER_NAME} ${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    echo "Deploying and starting container $AV_RTSP_SOURCE_CONTAINER_NAME done"

    echo -e "${GREEN}Deployment done${NC}"
    exit 0
fi

if [[ "${action}" == "undeploy" ]] ; then
    echo "Undeploying containers..."
    
    echo "Undeploying container $AV_RTMP_RTSP_CONTAINER_NAME..."
    docker container stop ${AV_RTMP_RTSP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_RTMP_RTSP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container $AV_RTMP_RTSP_CONTAINER_NAME done"

    echo "Undeploying container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    docker container stop ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done"

    echo "Undeploying container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    docker container stop ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done"

    echo "Undeploying container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    docker container stop ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done"

    echo "Undeploying container(s) $AV_FFMPEG_CONTAINER_NAME..."
    streamArray=(${AV_FFMPEG_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Stopping and removing container(s) ${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}..."
        docker container stop "${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}" > /dev/null 2> /dev/null  || true
        docker container rm "${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}" > /dev/null 2> /dev/null  || true
        echo "Stopping and removing container(s) ${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]} done..."
    done    
    docker image rm ${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container(s) $AV_FFMPEG_CONTAINER_NAME done"

    echo "Undeploying container(s) $AV_RECORDER_CONTAINER_NAME..."
    streamArray=(${AV_RECORDER_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Undeploying container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]}..."
        docker container stop ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} > /dev/null 2> /dev/null  || true
        docker container rm ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} > /dev/null 2> /dev/null  || true
        checkError
        echo "Undeploying container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} done"
    done    
    docker image rm ${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container(s) $AV_RECORDER_CONTAINER_NAME done"

    echo "Undeploying container(s) $AV_EDGE_CONTAINER_NAME..."
    streamArray=(${AV_EDGE_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Undeploying container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}..."
        docker container stop ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} > /dev/null 2> /dev/null  || true
        docker container rm ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} > /dev/null 2> /dev/null  || true
        checkError
        echo "Undeploying container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} done"
    done  
    docker image rm ${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container(s) $AV_EDGE_CONTAINER_NAME done"

    echo "Undeploying container $AV_WEBAPP_CONTAINER_NAME..."
    docker container stop ${AV_WEBAPP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_WEBAPP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container $AV_WEBAPP_CONTAINER_NAME done"

    echo "Undeploying container $AV_RTSP_SOURCE_CONTAINER_NAME..."
    docker container stop ${AV_RTSP_SOURCE_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_RTSP_SOURCE_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker image rm ${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME} > /dev/null 2> /dev/null  || true
    echo "Undeploying container $AV_RTSP_SOURCE_CONTAINER_NAME done"

    echo -e "${GREEN}Undeployment done${NC}"
    exit 0
fi

if [[ "${action}" == "status" ]] ; then
    echo "Checking containers status..."

    echo "Getting container $AV_RTMP_RTSP_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_RTMP_RTSP_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd"
    checkError
    echo "Getting container $AV_RTMP_RTSP_CONTAINER_NAME status done"

    echo "Getting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd"
    checkError
    echo "Getting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME status done"

    echo "Getting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd"
    checkError
    echo "Getting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME status done"

    echo "Getting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd"
    checkError
    echo "Getting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME status done"

    echo "Getting container(s) $AV_FFMPEG_CONTAINER_NAME status..."
    streamArray=(${AV_FFMPEG_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Getting container ${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]} status..."
        cmd="docker container inspect \"${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}\" --format '{{json .State.Status}}'"
        eval "$cmd"
        checkError
    done    
    echo "Getting container(s) $AV_FFMPEG_CONTAINER_NAME status done"

    echo "Getting container(s) $AV_RECORDER_CONTAINER_NAME status..."
    streamArray=(${AV_RECORDER_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Getting container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} status..."
        cmd="docker container inspect ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} --format '{{json .State.Status}}'"
        eval "$cmd"
        checkError
        echo "Getting container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} status done"
    done    
    echo "Getting container(s) $AV_RECORDER_CONTAINER_NAME status done"

    echo "Getting container(s) $AV_EDGE_CONTAINER_NAME status..."
    streamArray=(${AV_EDGE_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Getting container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} status..."
        cmd="docker container inspect ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} --format '{{json .State.Status}}'"
        eval "$cmd"
        checkError
        echo "Getting container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} status done"
    done    
    echo "Getting container $AV_EDGE_CONTAINER_NAME status done"

    echo "Getting container $AV_WEBAPP_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_WEBAPP_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd"
    checkError
    echo "Getting container $AV_WEBAPP_CONTAINER_NAME status done"

    echo "Getting container $AV_RTSP_SOURCE_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_RTSP_SOURCE_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd"
    checkError
    echo "Getting container $AV_RTSP_SOURCE_CONTAINER_NAME status done"

    echo -e "${GREEN}Container status done${NC}"
    exit 0
fi

if [[ "${action}" == "start" ]] ; then
    echo "Starting containers..."

    echo "Starting container $AV_RTMP_RTSP_CONTAINER_NAME..."
    cmd="docker container start ${AV_RTMP_RTSP_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Starting container $AV_RTMP_RTSP_CONTAINER_NAME done"

    echo "Starting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    cmd="docker container start ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Starting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done"

    echo "Starting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    cmd="docker container start ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Starting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done"

    echo "Starting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    cmd="docker container start ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Starting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done"

    echo "Starting container(s) $AV_FFMPEG_CONTAINER_NAME..."
    streamArray=(${AV_FFMPEG_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Starting container ${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker container start \"${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}\""
        eval "$cmd"
        checkError
    done    
    echo "Starting container(s) $AV_FFMPEG_CONTAINER_NAME done"

    echo "Starting container(s) $AV_RECORDER_CONTAINER_NAME..."
    streamArray=(${AV_RECORDER_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Starting container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker container start ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]}"
        eval "$cmd"
        checkError
        echo "Starting container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} done"
    done     
    echo "Starting container(s) $AV_RECORDER_CONTAINER_NAME done"

    echo "Starting container(s) $AV_EDGE_CONTAINER_NAME..."
    streamArray=(${AV_EDGE_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Starting container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker container start ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}"
        eval "$cmd"
        checkError
        echo "Starting container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} done"
    done     
    echo "Starting container(s) $AV_EDGE_CONTAINER_NAME done"

    echo "Starting container $AV_WEBAPP_CONTAINER_NAME status..."
    cmd="docker container start ${AV_WEBAPP_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Starting container $AV_WEBAPP_CONTAINER_NAME status done"

    echo "Starting container $AV_RTSP_SOURCE_CONTAINER_NAME status..."
    cmd="docker container start ${AV_RTSP_SOURCE_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Starting container $AV_RTSP_SOURCE_CONTAINER_NAME status done"

    echo -e "${GREEN}Container started${NC}"
    exit 0
fi

if [[ "${action}" == "stop" ]] ; then
    echo "Stopping containers..."
    
    echo "Stopping container $AV_RTMP_RTSP_CONTAINER_NAME..."
    cmd="docker container stop ${AV_RTMP_RTSP_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Stopping container $AV_RTMP_RTSP_CONTAINER_NAME done"

    echo "Stopping container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    cmd="docker container stop ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Stopping container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done"

    echo "Stopping container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    cmd="docker container stop ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Stopping container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done"

    echo "Stopping container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    cmd="docker container stop ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Stopping container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done"

    echo "Stopping container $AV_FFMPEG_CONTAINER_NAME..."
    streamArray=(${AV_FFMPEG_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Stopping container ${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker container stop \"${AV_FFMPEG_CONTAINER_NAME}-${streamArray[i]}\""
        eval "$cmd"
        checkError
    done 
    echo "Stopping container $AV_FFMPEG_CONTAINER_NAME done"

    echo "Stopping container(s) $AV_RECORDER_CONTAINER_NAME..."
    streamArray=(${AV_RECORDER_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Stopping container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker container stop ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]}"
        eval "$cmd"
        checkError
        echo "Stopping container ${AV_RECORDER_CONTAINER_NAME}-${streamArray[i]} done"
    done         
    echo "Stopping container(s) $AV_RECORDER_CONTAINER_NAME done"

    echo "Stopping container(s) $AV_EDGE_CONTAINER_NAME..."
    streamArray=(${AV_EDGE_STREAM_LIST//:/ })
    for i in "${!streamArray[@]}"
    do
        echo "Stopping container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}..."
        cmd="docker container stop ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]}"
        eval "$cmd"
        checkError
        echo "Stopping container ${AV_EDGE_CONTAINER_NAME}-${streamArray[i]} done"
    done         
    echo "Stopping container(s) $AV_EDGE_CONTAINER_NAME done"

    echo "Stopping container $AV_WEBAPP_CONTAINER_NAME status..."
    cmd="docker container stop ${AV_WEBAPP_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Stopping container $AV_WEBAPP_CONTAINER_NAME status done"

    echo "Stopping container $AV_RTSP_SOURCE_CONTAINER_NAME status..."
    cmd="docker container stop ${AV_RTSP_SOURCE_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    echo "Stopping container $AV_RTSP_SOURCE_CONTAINER_NAME status done"

    echo -e "${GREEN}Container stopped${NC}"
    exit 0
fi
