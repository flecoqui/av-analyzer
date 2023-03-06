#!/bin/sh
set -eu
BASH_SCRIPT=$(readlink -f "$0")
BASH_DIR=$(dirname "$BASH_SCRIPT")
SAVE_DIR=$(pwd)
cd "$BASH_DIR" > /dev/null
##############################################################################
# colors for formatting the ouput
##############################################################################
# shellcheck disable=SC2034
{
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
}
##############################################################################
#- function used to check whether an error occured
##############################################################################
checkError() {
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo -e "${RED}\nAn error occured exiting from the current bash${NC}"
        exit 1
    fi
}

##############################################################################
#- print functions
##############################################################################
printMessage(){
    echo  "${GREEN}$1${NC}" 
}
printWarning(){
    echo  "${YELLOW}$1${NC}" 
}
printError(){
    echo  "${RED}$1${NC}" 
}
printProgress(){
    echo  "${BLUE}$1${NC}" 
}
##############################################################################
#- encoding function
##############################################################################
encodevideowithpreamble(){
ARG_INPUT_FILE=$1
ARG_DURATION=$2
ARG_BITRATE=$3
ARG_FRAME_RATE=$4
INPUT_EXTENSION=$(echo "${ARG_INPUT_FILE##*.}")
INPUT_FOLDER=$(echo "${ARG_INPUT_FILE%/*}/")
INPUT_FILENAME=$(basename ${ARG_INPUT_FILE})
ARG_OUTPUT_FILE=${INPUT_FOLDER}encoded-$(echo $INPUT_FILENAME | sed -e "s/.${INPUT_EXTENSION}$/.mp4/")

    printMessage "Encoding video '${ARG_INPUT_FILE}' with a keyframe every second..."
    cmd="ffmpeg -i ${ARG_INPUT_FILE} -pix_fmt yuv420p -force_key_frames 00:00:00.000 -t ${ARG_DURATION} -filter:v fps=${ARG_FRAME_RATE}   -force_key_frames \"expr:gte(t,n_forced*1)\" -c:v libx264 -preset veryslow -x264-params "nal-hrd=cbr:force-cfr=1" -b:v ${ARG_BITRATE} -minrate ${ARG_BITRATE} -maxrate ${ARG_BITRATE} -bufsize 600k   -y ${ARG_OUTPUT_FILE}  -v error"
    echo "${cmd}"
    eval ${cmd}
    printMessage "Merging start chunck and video '${ARG_INPUT_FILE}'..."
    cmd="ffmpeg -i prevideo.mp4 -i encoded-${ARG_OUTPUT_FILE} -filter_complex \"[0:v] [1:v] concat=n=2:v=1 [v]\" -map \"[v]\"   -force_key_frames \"expr:gte(t,n_forced*1)\"  -c:v libx264 -preset veryslow -x264-params "nal-hrd=cbr:force-cfr=1" -b:v ${ARG_BITRATE} -minrate ${ARG_BITRATE} -maxrate ${ARG_BITRATE} -bufsize 600k   -y \"v-${ARG_OUTPUT_FILE}\" -v error"
    echo "${cmd}"
    eval ${cmd}
    cmd="rm encoded-${ARG_OUTPUT_FILE}"
    echo "${cmd}"
    eval ${cmd}
}
encodevideo(){
ARG_INPUT_FILE=$1
ARG_DURATION=$2
ARG_BITRATE=$3
ARG_FRAME_RATE=$4
INPUT_EXTENSION=$(echo "${ARG_INPUT_FILE##*.}")
echo "INPUT_EXTENSION $INPUT_EXTENSION"
INPUT_FOLDER=$(echo "${ARG_INPUT_FILE%/*}/")
echo "INPUT_FOLDER $INPUT_FOLDER"
INPUT_FILENAME=$(basename ${ARG_INPUT_FILE})
echo "INPUT_FILENAME $INPUT_FILENAME"
ARG_OUTPUT_FILE=${INPUT_FOLDER}encoded-$(echo $INPUT_FILENAME | sed -e "s/.${INPUT_EXTENSION}$/.mp4/")
echo "ARG_OUTPUT_FILE $ARG_OUTPUT_FILE"

    printMessage "Encoding video '${ARG_INPUT_FILE}' with a keyframe every second..."
    cmd="ffmpeg -i ${ARG_INPUT_FILE} -pix_fmt yuv420p -force_key_frames 00:00:00.000 -t ${ARG_DURATION} -filter:v fps=${ARG_FRAME_RATE}   -force_key_frames \"expr:gte(t,n_forced*1)\" -c:v libx264 -preset veryslow -x264-params "nal-hrd=cbr:force-cfr=1" -b:v ${ARG_BITRATE} -minrate ${ARG_BITRATE} -maxrate ${ARG_BITRATE} -bufsize 600k   -y ${ARG_OUTPUT_FILE}  -v error"
    echo "${cmd}"
    eval ${cmd}
}

displayframes(){
    ARG_INPUT_FILE=$1
    INPUT_EXTENSION=$(echo "${ARG_INPUT_FILE##*.}")
    INPUT_FOLDER=$(echo "${ARG_INPUT_FILE%/*}/")
    INPUT_FILENAME=$(basename ${ARG_INPUT_FILE})
    ARG_OUTPUT_FILE=${INPUT_FOLDER}encoded-$(echo $INPUT_FILENAME | sed -e "s/.${INPUT_EXTENSION}$/.mp4/")

    printMessage "Key Frame for file: encoded-${ARG_OUTPUT_FILE}"
    cmd="ffprobe -loglevel error -skip_frame nokey -select_streams v:0 -show_entries frame=pkt_pts_time -of csv=print_section=0 \"${ARG_OUTPUT_FILE}\""
    echo "${cmd}"
    eval ${cmd}
}

BITRATE=3000000
FRAME_RATE=25
printMessage "Creating start chunk..."
cmd="ffmpeg -f lavfi -i color=c=black:s=1080x1920:r=25:d=1 -force_key_frames 00:00:00.000 -map 0:v  -b:v ${BITRATE}  -vcodec libx264 -g $((FRAME_RATE-1)) -r ${FRAME_RATE}  -vf format=yuv420p -filter:v fps=${FRAME_RATE} -y ./input/prevideo.mp4 -v error"
echo "${cmd}"
eval ${cmd}


DURATION=0
FILE_LIST=""
for i in $(echo ${FILE_LIST} | sed 's/,/ /g')
do
    NINPUT_FILE=$i
    INPUT_EXTENSION=$(echo "${NINPUT_FILE##*.}")
    INPUT_FILE=$(echo $NINPUT_FILE | sed -e "s/.${INPUT_EXTENSION}$/.mp4/")
    printMessage "Cropping airport video '${NINPUT_FILE}'..."
    cmd="ffmpeg -i ${NINPUT_FILE} -filter:v \"crop=594:1056:656:0\"   s-${NINPUT_FILE} -y -v error"
    echo "${cmd}"
    eval ${cmd}
    printMessage "Upscaling airport video '${NINPUT_FILE}'..."
    cmd="ffmpeg -i s-${NINPUT_FILE} -vf scale=1080:1920  -preset slow -crf 18  ${INPUT_FILE} -y -v error"
    echo "${cmd}"
    eval ${cmd}

    cmd="rm s-${NINPUT_FILE}"
    echo "${cmd}"
    eval ${cmd}

    encodevideo ${INPUT_FILE} ${DURATION} ${BITRATE} ${FRAME_RATE}
    displayframes ${INPUT_FILE}
done

DURATION=120
FILE_LIST="./input/camera-300s.mkv,./input/lots_015.mkv,./input/lots_284.mkv"
for i in $(echo ${FILE_LIST} | sed 's/,/ /g')
do
    INPUT_FILE=$i
    encodevideo ${INPUT_FILE} ${DURATION} ${BITRATE} ${FRAME_RATE}
    displayframes ${INPUT_FILE}
done
cmd="rm ./input/prevideo.mp4"
echo "${cmd}"
eval ${cmd}

cd "$SAVE_DIR" > /dev/null