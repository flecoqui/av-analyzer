#!/bin/sh
##########################################################################################################################################################################################
#- Purpose: Script used to install pre-requisites, deploy/undeploy service, start/stop service, test service
#- Parameters are:
#- [-a] action - value: login, build, create, remove, start, status, stop, status, logs vminstall, vmdeploy, vmundeploy, vmcreate, vmremove, vmstart, vmstop, vmstatus, vmlogs
#- [-c] configuration file - which contains the list of path of each evatool.sh to call (avtool.env by default)
#
# executable
###########################################################################################################################################################################################
set -eu
#BASH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BASH_SCRIPT=`readlink -f "$0"`
BASH_DIR=`dirname "$BASH_SCRIPT"`
cd "$BASH_DIR"

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
#- azure Login 
##############################################################################
azLogin() {
    # Check if current process's user is logged on Azure
    # If no, then triggers az login
    echo "AZURE_SUBSCRIPTION_ID $AZURE_SUBSCRIPTION_ID"
    echo "AZURE_TENANT_ID $AZURE_TENANT_ID"
    
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        printError "Variable AZURE_SUBSCRIPTION_ID not set"
        az login
        # get Azure Subscription and Tenant Id if already connected
        AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
        AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true        
    fi
    if [ -z "$AZURE_TENANT_ID" ]; then
        printError "Variable AZURE_TENANT_ID not set"
        az login
        # get Azure Subscription and Tenant Id if already connected
        AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
        AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true        
    fi
    azOk=true
    az account set -s "$AZURE_SUBSCRIPTION_ID" 2>/dev/null || azOk=false
    if [ ${azOk} = false ] 
    then
        printWarning "Need to az login"
        az login --tenant "$AZURE_TENANT_ID"
    fi

    azOk=true
    az account set -s "$AZURE_SUBSCRIPTION_ID"   || azOk=false
    if [ ${azOk} = false ] 
    then
        echo -e "unknown error"
        exit 1
    fi
}
##############################################################################
#- checkLoginAndSubscription 
##############################################################################
checkLoginAndSubscription() {
    az account show -o none
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo -e "\nYou seems disconnected from Azure, running 'az login'."
        az login -o none
    fi
    CURRENT_SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
    if [ -z "$AZURE_SUBSCRIPTION_ID" ] || [ "$AZURE_SUBSCRIPTION_ID" != "$CURRENT_SUBSCRIPTION_ID" ]
    then
        # query subscriptions
        echo -e "\nYou have access to the following subscriptions:"
        az account list --query '[].{name:name,"subscription Id":id}' --output table

        echo -e "\nYour current subscription is:"
        az account show --query '[name,id]'
        # shellcheck disable=SC2154
        if [ ${silentmode} = false ] || [ -z "$CURRENT_SUBSCRIPTION_ID" ]
        then        
            echo -e "
            You will need to use a subscription with permissions for creating service principals (owner role provides this).
            If you want to change to a different subscription, enter the name or id.
            Or just press enter to continue with the current subscription."
            read -r -p ">> " SUBSCRIPTION_ID

            if ! test -z "$SUBSCRIPTION_ID"
            then 
                az account set -s "$SUBSCRIPTION_ID"
                echo -e "\nNow using:"
                az account show --query '[name,id]'
                CURRENT_SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
            fi
        fi
    fi
}
##############################################################################
#- updateConfigurationFile: Update configuration file
#  arg 1: Configuration file path
#  arg 2: Variable Name
#  arg 3: Value
##############################################################################
updateConfigurationFile(){
    configFile="$1"
    variable="$2"
    value="$3"

    count=$(grep "${variable}=.*" -c < "$configFile") || true
    if [ "${count}" = 1 ] 
    then
        escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
        sed -i "s/${variable}=.*/${variable}=${escaped_value}/g" "${configFile}" 
    elif [ "${count}" = 0 ]
    then
        echo "${variable}=${value}" >> "${configFile}"
    fi
}
##############################################################################
#- invokeRemoteCommand: Launch a command on the virtual machine
#  arg 1: resource group
#  arg 2: virtual machine name
#  arg 3: script
##############################################################################
invokeRemoteCommand(){
    resourcegroup="$1"
    virtualmachine="$2"
    script="$3"
    
    cmd="az vm run-command invoke -g $resourcegroup -n $virtualmachine --command-id RunShellScript --scripts \"$script\" " 
    echo "$cmd"
    az vm run-command invoke -g $resourcegroup -n $virtualmachine --command-id RunShellScript --scripts "$script"  > "${AV_TEMPDIR}/result.txt"
    echo "RESULT:"
    cat ${AV_TEMPDIR}/result.txt
    #printf "$result"
    echo "CODE:"
    printf "$(cat ${AV_TEMPDIR}/result.txt | jq '.value[0].code' | sed 's/u001b/033/g' | sed 's/%//g')" || true
    echo ""
    echo "STDOUT:" 
    printf "$(cat ${AV_TEMPDIR}/result.txt | jq '.value[0].message' | grep -o -P '(?<=(stdout\])).*(?=\[stderr)' | sed 's/u001b/033/g' | sed 's/%//g')"  || true
    echo ""
    echo "STDERR:"
    printf "$(cat ${AV_TEMPDIR}/result.txt | jq '.value[0].message' | grep -o -P '(?<=(stderr\])).*' | sed 's/u001b/033/g' | sed 's/%//g')" || true
    echo ""
    checkError
}
##############################################################################
#- pushImage: push image on Azure Container Registry
#  arg 1: image
#  arg 2: image version
#  arg 3: image latest version
#  arg 4: Azure Container Registry
##############################################################################
pushImage(){
    image="$1"
    version="$2"
    latestversion="$3"
    acr="$4"

    cmd="docker tag ${image}:${version} ${acr}/${image}:${version}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    cmd="docker tag ${image}:${version} ${acr}/${image}:${latestversion}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${acr}" ]
    then
        cmd="docker push ${acr}/${image}:${version}" 
        echo "$cmd"
        eval "$cmd"
        checkError
        cmd="docker push ${acr}/${image}:${latestversion}" 
        echo "$cmd"
        eval "$cmd"
        checkError
    fi
}
##############################################################################
#- tagImage: tag local image
#  arg 1: image
#  arg 2: image version
#  arg 3: image latest version
##############################################################################
tagImage(){
    image="$1"
    version="$2"
    latestversion="$3"

    cmd="docker tag ${image}:${version} ${image}:${version}" 
    echo "$cmd"
    eval "$cmd"
    checkError
    cmd="docker tag ${image}:${version} ${image}:${latestversion}" 
    echo "$cmd"
    eval "$cmd"
    checkError
}
##############################################################################
#- getInputFrame: get input frame: nframe (no frame), sframe (start frame), kframe (key frame)
#  arg 1: input
##############################################################################
getInputFrame(){
    input="$1"
    type=$(echo "${input}" | cut -c1-6)
    if [ "$type" = "nframe" ] || [ "$type" = "sframe" ] || [ "$type" = "kframe" ] 
    then 
        echo "${type}"
    else
        echo "nframe"
    fi 
}
##############################################################################
#- getInputType: get input type: file, rtsp, rtmp, http
#  arg 1: input
##############################################################################
getInputType(){
    input="$1"
    type=$(echo "${input}" | cut -c8-11)
    if [ "$type" = "http" ] || [ "$type" = "rtsp" ] || [ "$type" = "rtmp" ] || [ "$type" = "file" ]
    then 
        echo "${type}"
    else
        echo "file"
    fi 
}
##############################################################################
#- getInputFile: get input file
#  arg 1: input
##############################################################################
getInputFile(){
    input="$1"
    type=$(echo "${input}" | cut -c8-11)
    if [ "$type" = "http" ] || [ "$type" = "rtsp" ] || [ "$type" = "rtmp" ] || [ "$type" = "file" ]
    then 
        echo "${input}" | cut -c15-256
    else
        echo "${input}"
    fi 
}
##############################################################################
#- readConfigurationFile: Update configuration file
#  arg 1: Configuration file path
##############################################################################
readConfigurationFile(){
    file="$1"

    #set -o allexport
    # shellcheck disable=SC1090
    #source "$file"
    #. "$file"
    #export $(grep -v '^#' "$file" | xargs)
   # set +o allexport


    export $(grep AZURE_PREFIX "$file")
    export $(grep AZURE_REGION "$file")
    export $(grep AZURE_COMPUTER_VISION_SKU "$file")
    export $(grep AZURE_CUSTOM_VISION_SKU "$file")
    export $(grep AZURE_AUTHENTICATION_TYPE "$file")

    if [ -f "${BASH_DIR}/../../../config/out${AZURE_PREFIX}key.pub" ]
    then
        export AZURE_SSH_PUBLIC_KEY="\"$(cat ${BASH_DIR}/../../../config/out${AZURE_PREFIX}key.pub)\""
    fi
    if [ -f "${BASH_DIR}/../../../config/out${AZURE_PREFIX}key" ]
    then
        export AZURE_SSH_PRIVATE_KEY="\"$(cat ${BASH_DIR}/../../../config/out${AZURE_PREFIX}key)\""
    fi

    export $(grep AZURE_LOCAL_IP_ADDRESS "$file")
    export $(grep AZURE_LOGIN "$file")
    export $(grep AZURE_AUTHENTICATION_TYPE "$file")
    export $(grep AZURE_VM_SIZE "$file")
    export $(grep AZURE_PORT_HTTP "$file")
    export $(grep AZURE_PORT_WEBAPP_HTTP "$file")
    export $(grep AZURE_PORT_SSL "$file")
    export $(grep AZURE_PORT_HLS "$file")
    export $(grep AZURE_PORT_RTMP "$file")
    export $(grep AZURE_PORT_RTSP "$file")
    export $(grep AZURE_RESOURCE_GROUP "$file")
    export $(grep AZURE_STORAGE_ACCOUNT "$file")
    export $(grep AZURE_CONTENT_STORAGE_CONTAINER "$file")
    export $(grep AZURE_RECORD_STORAGE_CONTAINER "$file")
    export $(grep AZURE_RESULT_STORAGE_CONTAINER "$file")
    export $(grep AZURE_COMPUTER_VISION "$file")
    export $(grep AZURE_COMPUTER_VISION_KEY "$file")
    export $(grep AZURE_COMPUTER_VISION_ENDPOINT "$file")
    export $(grep AZURE_CUSTOM_VISION_TRAINING "$file")
    export $(grep AZURE_CUSTOM_VISION_TRAINING_KEY "$file")
    export $(grep AZURE_CUSTOM_VISION_TRAINING_ENDPOINT "$file")
    export $(grep AZURE_CUSTOM_VISION_PREDICTION "$file")
    export $(grep AZURE_CUSTOM_VISION_PREDICTION_KEY "$file")
    export $(grep AZURE_CUSTOM_VISION_PREDICTION_ENDPOINT "$file")
    export $(grep AZURE_CONTAINER_REGISTRY "$file")
    export $(grep AZURE_ACR_LOGIN_SERVER "$file")
    export $(grep AZURE_VIRTUAL_MACHINE_NAME "$file")
    export $(grep AZURE_VIRTUAL_MACHINE_HOSTNAME "$file")
    export $(grep AZURE_CONTENT_STORAGE_CONTAINER_URL "$file")
    export $(grep AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN "$file")
    export $(grep AZURE_RECORD_STORAGE_CONTAINER_URL "$file")
    export $(grep AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN "$file")
    export $(grep AZURE_RESULT_STORAGE_CONTAINER_URL "$file")
    export $(grep AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN "$file")



    export $(grep AV_TEMPDIR "$file")
    export $(grep AV_FLAVOR "$file")
    export $(grep AV_IMAGE_FOLDER "$file")

    export $(grep AV_RTMP_RTSP_CONTAINER_NAME "$file")
    export $(grep AV_RTMP_RTSP_IMAGE_NAME "$file") 
    export $(grep AV_RTMP_RTSP_COMPANYNAME "$file")
    export $(grep AV_RTMP_RTSP_HOSTNAME "$file")
    export $(grep AV_RTMP_RTSP_PORT_HLS "$file")
    export $(grep AV_RTMP_RTSP_PORT_HTTP "$file")
    export $(grep AV_RTMP_RTSP_PORT_SSL "$file")
    export $(grep AV_RTMP_RTSP_PORT_RTMP "$file")
    export $(grep AV_RTMP_RTSP_PORT_RTSP "$file")
    export $(grep AV_RTMP_RTSP_STREAM_LIST "$file")

    export $(grep AV_MODEL_YOLO_ONNX_PORT_HTTP "$file")
    export $(grep AV_MODEL_YOLO_ONNX_IMAGE_NAME "$file")
    export $(grep AV_MODEL_YOLO_ONNX_CONTAINER_NAME "$file")

    export $(grep AV_MODEL_COMPUTER_VISION_PORT_HTTP "$file")
    export $(grep AV_MODEL_COMPUTER_VISION_IMAGE_NAME "$file")
    export $(grep AV_MODEL_COMPUTER_VISION_CONTAINER_NAME "$file")
    export $(grep AV_MODEL_COMPUTER_VISION_URL "$file")
    export $(grep AV_MODEL_COMPUTER_VISION_KEY "$file")

    export $(grep AV_MODEL_CUSTOM_VISION_PORT_HTTP "$file")
    export $(grep AV_MODEL_CUSTOM_VISION_IMAGE_NAME "$file")
    export $(grep AV_MODEL_CUSTOM_VISION_CONTAINER_NAME "$file")
    export $(grep AV_MODEL_CUSTOM_VISION_URL "$file")
    export $(grep AV_MODEL_CUSTOM_VISION_KEY "$file")

    export $(grep AV_EXTRACT_FRAME_IMAGE_NAME "$file")
    export $(grep AV_EXTRACT_FRAME_CONTAINER_NAME "$file")

    export $(grep AV_FFMPEG_IMAGE_NAME "$file")
    export $(grep AV_FFMPEG_CONTAINER_NAME "$file")
    export $(grep AV_FFMPEG_LOCAL_FILE "$file")
    export $(grep AV_FFMPEG_VOLUME "$file")
    export $(grep AV_FFMPEG_STREAM_LIST "$file")
    export $(grep AV_FFMPEG_INPUT_LIST "$file")

    export $(grep AV_RECORDER_IMAGE_NAME "$file")
    export $(grep AV_RECORDER_CONTAINER_NAME "$file")
    export $(grep AV_RECORDER_INPUT_URL "$file")
    export $(grep AV_RECORDER_PERIOD "$file")
    export $(grep AV_RECORDER_STORAGE_URL "$file")
    export $(grep AV_RECORDER_STORAGE_SAS_TOKEN "$file")
    export $(grep AV_RECORDER_STORAGE_FOLDER "$file")
    export $(grep AV_RECORDER_VOLUME "$file")
    export $(grep AV_RECORDER_STREAM_LIST "$file")


    export $(grep AV_EDGE_IMAGE_NAME "$file")
    export $(grep AV_EDGE_CONTAINER_NAME "$file")
    export $(grep AV_EDGE_INPUT_URL "$file")
    export $(grep AV_EDGE_PERIOD "$file")
    export $(grep AV_EDGE_STORAGE_URL "$file")
    export $(grep AV_EDGE_STORAGE_SAS_TOKEN "$file")
    export $(grep AV_EDGE_STORAGE_FOLDER "$file")
    export $(grep AV_EDGE_MODEL_URL "$file")
    export $(grep AV_EDGE_VOLUME "$file")
    export $(grep AV_EDGE_STREAM_LIST "$file")

    export $(grep AV_WEBAPP_IMAGE_NAME "$file")
    export $(grep AV_WEBAPP_CONTAINER_NAME "$file")
    export $(grep AV_WEBAPP_PORT_HTTP "$file")
    export $(grep AV_WEBAPP_STORAGE_RESULT_URL "$file")
    export $(grep AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN "$file")
    export $(grep AV_WEBAPP_STORAGE_RECORD_URL "$file")
    export $(grep AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN "$file")
    export $(grep AV_WEBAPP_FOLDER "$file")
    export $(grep AV_WEBAPP_STREAM_LIST "$file")
    export $(grep AV_WEBAPP_STREAM_URL_PREFIX "$file")

    export $(grep AV_RTSP_SOURCE_IMAGE_NAME "$file")
    export $(grep AV_RTSP_SOURCE_CONTAINER_NAME "$file")
    export $(grep AV_RTSP_SOURCE_PORT "$file")

    export $(grep AV_RTSP_SERVER_IMAGE_NAME "$file")
    export $(grep AV_RTSP_SERVER_CONTAINER_NAME "$file")
    export $(grep AV_RTSP_SERVER_PORT_RTSP "$file")
    export $(grep AV_RTSP_SERVER_FILE_LIST "$file")

    # export $(<"$file")
    # export AZURE_SSH_PUBLIC_KEY="\"$(cat ${BASH_DIR}/../../../config/out${AZURE_PREFIX}key.pub)\""
    # export AZURE_SSH_PRIVATE_KEY="\"$(cat ${BASH_DIR}/../../../config/out${AZURE_PREFIX}key)\""

}
#######################################################
#- function used to print out script usage
#######################################################
usage() {
    echo
    echo "Edge Video Analytics Tool (evatool):"
    echo "Arguments:"
    echo -e " -a  Sets EVA Tool action {install, login, build, create, remove, start, stop, status, logs, vminstall, vmdeploy, vmundeploy, vmcreate, vmremove, vmstart, vmstop, vmstatus, vmlogs}"
    echo -e " -c  Sets the AV Tool configuration file"
    echo -e " -u  Sets the virtual machine user"
    echo
    echo "Example:"
    echo -e " bash ./evatool.sh -a build "
    echo -e " bash ./evatool.sh -a create "
    echo -e " bash ./evatool.sh -a vminstall -u vmadmin "
    
}
###########################################################
#- function used to log information in the virtual machine
###########################################################
log()
{
	# If you want to enable this logging, uncomment the line below and specify your logging key 
	#curl -X POST -H "content-type:text/plain" --data-binary "$(date) | ${HOSTNAME} | $1" https://logs-01.loggly.com/inputs/${LOGGING_KEY}/tag/redis-extension,${HOSTNAME}
	echo "$1"
    if [ ! -d /eva ]
    then
        mkdir /eva
    fi
    if [ ! -d /eva/log ]
    then
        mkdir /eva/log
    fi
	echo "$1" >> /eva/log/install.log
}
LUN=4
LATEST_IMAGE_VERSION="latest"
action=
configuration_file=${BASH_DIR}/../../../config/.avtoolconfig
vmuser=
while getopts "a:c:u:hq" opt; do
    case $opt in
    a) action=$OPTARG ;;
    c) configuration_file=$OPTARG ;;    
    u) vmuser=$OPTARG ;;    
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
if [ $# -eq 0 ] || [ ! -n $action ] || [ ! -n $configuration_file ] 
then
    echo "Required parameters are missing"
    usage
    exit 1
fi
if [ $action != login ] && [  $action != build ] && [ $action != start ] && [ $action != stop ] && [ $action != status ] && [ $action != logs ] && [ $action != create ] && [ $action != remove ] && [ $action != vmdeploy ] && [ $action != vmundeploy ] && [ $action != vminstall ] && [ $action != vmbuild ] && [ $action != vmcreate ] && [ $action != vmremove ] && [ $action != vmstart ] && [ $action != vmstop ] && [ $action != vmstatus ] && [ $action != vmlogs ] 
then
    echo "Required action is missing, values: login, build, deploy, undeploy, deploycontainer, start, stop, status"
    usage
    exit 1
fi

if [ "$action" = "vminstall" ]
then
    log "Installation script start : $(date)"

    log "Create folders"
    mkdir /git 2>/dev/null || true
    mkdir /temp 2>/dev/null || true
    mkdir /eva 2>/dev/null || true
    mkdir /install 2>/dev/null || true
    mkdir /config 2>/dev/null || true
    mkdir /content 2>/dev/null || true
    chmod  -R o+rwx  /config 2>/dev/null || true
    chmod  -R o+rwx  /content 2>/dev/null || true
    mkdir /eva/log 2>/dev/null || true
    chmod  -R o+rwx  /eva/log 2>/dev/null || true
    log "Folders created"
    
    log "Install git"
    apt-get -y update
    apt-get -y install git
    log "git installed"
    
    log "Install ffmpeg"
    apt-get -y update
    apt-get -y install ffmpeg
    log "ffmpeg installed"
    
    log "Install jq"
    apt-get -y update
    apt-get -y install jq
    log "jq installed"

    log "Configure network"
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
    iptables -A INPUT -p tcp --dport 8084 -j ACCEPT
    iptables -A INPUT -p tcp --dport 8554 -j ACCEPT
    iptables -A INPUT -p udp --dport 8554 -j ACCEPT
    iptables -A INPUT -p tcp --dport 554 -j ACCEPT
    iptables -A INPUT -p udp --dport 554 -j ACCEPT
    iptables -A INPUT -p udp --dport 7001 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp --dport 1935 -j ACCEPT
    log "Network configured"
    
    log "Install Azure CLI"
    apt-get -y update
    apt-get -y install ca-certificates curl apt-transport-https lsb-release gnupg -y
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    apt-get update
    apt-get install azure-cli -y
    log "azure-cli installed"
    
    log "Install Scripts"
    cp ${BASH_SCRIPT} /install/evatool.sh
    chmod 0755 /install/evatool.sh
    log "Scripts installed"

    log "Install Docker"
    apt-get -y update
    apt-get -y upgrade
    apt-get -y install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get -y update
    apt-cache policy docker-ce
    apt-get -y install docker-ce
    usermod -aG docker $vmuser
    systemctl status docker
    log "Docker installed"

    log "Create partition"
    partition=$(lsblk -o NAME,HCTL,SIZE,MOUNTPOINT | grep -i 'sd' | grep -i ":$LUN " | grep -o '^\S*')
    if [ ! -z $partition ];
    then
        log "partion: $partition"
        mountpart=$(lsblk -o NAME,HCTL,SIZE,MOUNTPOINT | grep -i "${partition}1" || true )
        if [ -z "$mountpart" ];
        then
            log "parted /dev/${partition} --script mklabel gpt mkpart xfspart xfs 0% 100%"
            parted /dev/${partition} --script mklabel gpt mkpart xfspart xfs 0% 100%
            log "mkfs.xfs /dev/${partition}1"
            mkfs.xfs /dev/${partition}1
            log "partprobe /dev/${partition}1"
            partprobe /dev/${partition}1
            log "systemctl stop docker"
            systemctl stop docker
            log "mv /var/lib/docker /var/lib/docker-backup"
            mv /var/lib/docker /var/lib/docker-backup
            log "mkdir /var/lib/docker"
            mkdir /var/lib/docker
            log "mount /dev/sda1 /var/lib/docker"
            mount /dev/sda1 /var/lib/docker
            log "cp -rf /var/lib/docker-backup/. /var/lib/docker"
            cp -rf /var/lib/docker-backup/. /var/lib/docker
            log "systemctl start docker"
            systemctl start docker
        fi
    fi
    log "Create partition done"

    log "Installation successful"
    exit 0
fi

# get Azure Subscription and Tenant Id if already connected
AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true

# check if configuration file is set 
if [ ! -n ${AZURE_SUBSCRIPTION_ID} ] || [ ! -n ${AZURE_TENANT_ID}  ]
then
    printError "Connection to Azure required, launching 'az login'"
    printMessage "Login..."
    azLogin
    checkLoginAndSubscription
    printMessage "Login done"    
    AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv 2> /dev/null) || true
    AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2> /dev/null) || true
fi



if [ $configuration_file ]
then
    if [ ! -f "$configuration_file" ]; then
        printMessage "Create configuration file $configuration_file with default parameters"
        AZURE_PREFIX="eva$(shuf -i 1000-9999 -n 1)"
        AZURE_REGION="eastus"
        AZURE_COMPUTER_VISION_SKU="S1"
        AZURE_CUSTOM_VISION_SKU="S0"
        AZURE_AUTHENTICATION_TYPE="sshPublicKey"
        if [ ! -f ${BASH_DIR}/../../../config/out${AZURE_PREFIX}key.pub ]
        then
            ssh-keygen -t rsa -b 2048 -f ${BASH_DIR}/../../../config/out${AZURE_PREFIX}key -q -P ""
        fi
        #AZURE_SSH_PUBLIC_KEY="\"$(cat ${BASH_DIR}/../../../config/out${AZURE_PREFIX}key.pub)\""
        #AZURE_SSH_PRIVATE_KEY="\"$(cat ${BASH_DIR}/../../../config/out${AZURE_PREFIX}key)\""
        AZURE_LOCAL_IP_ADDRESS=$(curl -s ifconfig.me 2>/dev/null) || true
        AZURE_LOGIN="evaadmin"
        AZURE_AUTHENTICATION_TYPE="sshPublicKey"
        # Select 8 vpus VM for two channels with recording
        #
        AZURE_VM_SIZE="Standard_F8s_v2"
        AZURE_PORT_HTTP=80
        AZURE_PORT_WEBAPP_HTTP=8084 
        AZURE_PORT_SSL=443 
        AZURE_PORT_HLS=8080 
        AZURE_PORT_RTMP=1935
        AZURE_PORT_RTSP=8554

        AZURE_RESOURCE_GROUP=""
        AZURE_STORAGE_ACCOUNT=""
        AZURE_CONTENT_STORAGE_CONTAINER=""
        AZURE_RECORD_STORAGE_CONTAINER=""
        AZURE_RESULT_STORAGE_CONTAINER=""
        AZURE_COMPUTER_VISION=""
        AZURE_COMPUTER_VISION_KEY=""
        AZURE_COMPUTER_VISION_ENDPOINT=""
        AZURE_CUSTOM_VISION_TRAINING=""
        AZURE_CUSTOM_VISION_TRAINING_KEY=""
        AZURE_CUSTOM_VISION_TRAINING_ENDPOINT=""
        AZURE_CUSTOM_VISION_PREDICTION=""
        AZURE_CUSTOM_VISION_PREDICTION_KEY=""
        AZURE_CUSTOM_VISION_PREDICTION_ENDPOINT=""
        AZURE_CONTAINER_REGISTRY=""
        AZURE_ACR_LOGIN_SERVER=""
        AZURE_VIRTUAL_MACHINE_NAME=""
        AZURE_VIRTUAL_MACHINE_HOSTNAME=""
        AZURE_CONTENT_STORAGE_CONTAINER_URL=""
        AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN=""
        AZURE_RECORD_STORAGE_CONTAINER_URL=""
        AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN=""
        AZURE_RESULT_STORAGE_CONTAINER_URL=""
        AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN=""



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
        AV_RTMP_RTSP_STREAM_LIST=camera1,camera2

        AV_MODEL_YOLO_ONNX_PORT_HTTP=8081
        AV_MODEL_YOLO_ONNX_IMAGE_NAME=http-yolov3-onnx-image
        AV_MODEL_YOLO_ONNX_CONTAINER_NAME=http-yolov3-onnx-container

        AV_MODEL_COMPUTER_VISION_PORT_HTTP=8082
        AV_MODEL_COMPUTER_VISION_IMAGE_NAME=computer-vision-image
        AV_MODEL_COMPUTER_VISION_CONTAINER_NAME=computer-vision-container
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
        AV_FFMPEG_STREAM_LIST=camera1,camera2
        AV_FFMPEG_INPUT_LIST=kframe:rtsp://camera-300s.mp4,sframe:rtsp://lots_015.mp4

        AV_EXTRACT_FRAME_IMAGE_NAME=extractframe-image
        AV_EXTRACT_FRAME_CONTAINER_NAME=extractframe-container
        
        AV_RECORDER_IMAGE_NAME=recorder-image
        AV_RECORDER_CONTAINER_NAME=recorder-container
        AV_RECORDER_INPUT_URL=""
        AV_RECORDER_PERIOD=10
        AV_RECORDER_STORAGE_URL="https://to_be_completed.blob.core.windows.net/to_be_completed"
        AV_RECORDER_STORAGE_SAS_TOKEN="?to_be_completed"
        AV_RECORDER_STORAGE_FOLDER=/version1.0
        AV_RECORDER_VOLUME=/tempvol
        AV_RECORDER_STREAM_LIST=camera1,camera2

        AV_EDGE_IMAGE_NAME=edge-image
        AV_EDGE_CONTAINER_NAME=edge-container
        AV_EDGE_INPUT_URL=""
        AV_EDGE_PERIOD=25
        AV_EDGE_STORAGE_URL="https://to_be_completed.blob.core.windows.net/to_be_completed"
        AV_EDGE_STORAGE_SAS_TOKEN="?to_be_completed"
        AV_EDGE_STORAGE_FOLDER=/version1.0
        AV_EDGE_MODEL_URL=""
        AV_EDGE_VOLUME=/tempvol
        AV_EDGE_STREAM_LIST=camera1,camera2

        AV_WEBAPP_IMAGE_NAME=webapp-image
        AV_WEBAPP_CONTAINER_NAME=webapp-container
        AV_WEBAPP_PORT_HTTP=8084
        AV_WEBAPP_STORAGE_RESULT_URL="https://to_be_completed.blob.core.windows.net/to_be_completed"
        AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN="to_be_completed"
        AV_WEBAPP_STORAGE_RECORD_URL="https://to_be_completed.blob.core.windows.net/to_be_completed"
        AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN="to_be_completed"
        AV_WEBAPP_FOLDER=version1.0
        AV_WEBAPP_STREAM_LIST=camera1,camera2
        AV_WEBAPP_STREAM_URL_PREFIX=""

        AV_RTSP_SOURCE_IMAGE_NAME=rtsp-source-image
        AV_RTSP_SOURCE_CONTAINER_NAME=rtsp-source-container
        AV_RTSP_SOURCE_PORT=554

        AV_RTSP_SERVER_IMAGE_NAME=rtsp-server-image
        AV_RTSP_SERVER_CONTAINER_NAME=rtsp-server-container
        AV_RTSP_SERVER_PORT_RTSP=554
        AV_RTSP_SERVER_FILE_LIST=camera-300s.mp4,lots_015.mp4

        cat > "$configuration_file" << EOF
AZURE_PREFIX=${AZURE_PREFIX}
AZURE_REGION=${AZURE_REGION}
AZURE_COMPUTER_VISION_SKU=${AZURE_COMPUTER_VISION_SKU}
AZURE_CUSTOM_VISION_SKU=${AZURE_CUSTOM_VISION_SKU}
AZURE_AUTHENTICATION_TYPE=${AZURE_AUTHENTICATION_TYPE}
AZURE_LOCAL_IP_ADDRESS=${AZURE_LOCAL_IP_ADDRESS}
AZURE_LOGIN=${AZURE_LOGIN}
AZURE_AUTHENTICATION_TYPE=${AZURE_AUTHENTICATION_TYPE}
AZURE_VM_SIZE=${AZURE_VM_SIZE}
AZURE_PORT_HTTP=${AZURE_PORT_HTTP} 
AZURE_PORT_WEBAPP_HTTP=${AZURE_PORT_WEBAPP_HTTP} 
AZURE_PORT_SSL=${AZURE_PORT_SSL} 
AZURE_PORT_HLS=${AZURE_PORT_HLS} 
AZURE_PORT_RTMP=${AZURE_PORT_RTMP}
AZURE_PORT_RTSP=${AZURE_PORT_RTSP}

AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}
AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT}
AZURE_CONTENT_STORAGE_CONTAINER=${AZURE_CONTENT_STORAGE_CONTAINER}
AZURE_RECORD_STORAGE_CONTAINER=${AZURE_RECORD_STORAGE_CONTAINER}
AZURE_RESULT_STORAGE_CONTAINER=${AZURE_RESULT_STORAGE_CONTAINER}
AZURE_COMPUTER_VISION=${AZURE_COMPUTER_VISION}
AZURE_COMPUTER_VISION_KEY=${AZURE_COMPUTER_VISION_KEY}
AZURE_COMPUTER_VISION_ENDPOINT=${AZURE_COMPUTER_VISION_ENDPOINT}
AZURE_CUSTOM_VISION_TRAINING=${AZURE_CUSTOM_VISION_TRAINING}
AZURE_CUSTOM_VISION_TRAINING_KEY=${AZURE_CUSTOM_VISION_TRAINING_KEY}
AZURE_CUSTOM_VISION_TRAINING_ENDPOINT=${AZURE_CUSTOM_VISION_TRAINING_ENDPOINT}
AZURE_CUSTOM_VISION_PREDICTION=${AZURE_CUSTOM_VISION_PREDICTION}
AZURE_CUSTOM_VISION_PREDICTION_KEY=${AZURE_CUSTOM_VISION_PREDICTION_KEY}
AZURE_CUSTOM_VISION_PREDICTION_ENDPOINT=${AZURE_CUSTOM_VISION_PREDICTION_ENDPOINT}
AZURE_CONTAINER_REGISTRY=${AZURE_CONTAINER_REGISTRY}
AZURE_ACR_LOGIN_SERVER=${AZURE_ACR_LOGIN_SERVER}
AZURE_VIRTUAL_MACHINE_NAME=${AZURE_VIRTUAL_MACHINE_NAME}
AZURE_VIRTUAL_MACHINE_HOSTNAME=${AZURE_VIRTUAL_MACHINE_HOSTNAME}
AZURE_CONTENT_STORAGE_CONTAINER_URL=${AZURE_CONTENT_STORAGE_CONTAINER_URL}
AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN=${AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN}
AZURE_RECORD_STORAGE_CONTAINER_URL=${AZURE_RECORD_STORAGE_CONTAINER_URL}
AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN=${AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN}
AZURE_RESULT_STORAGE_CONTAINER_URL=${AZURE_RESULT_STORAGE_CONTAINER_URL}
AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN=${AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN}


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
AV_FFMPEG_INPUT_LIST=${AV_FFMPEG_INPUT_LIST}

AV_EXTRACT_FRAME_IMAGE_NAME=${AV_EXTRACT_FRAME_IMAGE_NAME}
AV_EXTRACT_FRAME_CONTAINER_NAME=${AV_EXTRACT_FRAME_CONTAINER_NAME}

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

AV_RTSP_SERVER_IMAGE_NAME=${AV_RTSP_SERVER_IMAGE_NAME}
AV_RTSP_SERVER_CONTAINER_NAME=${AV_RTSP_SERVER_CONTAINER_NAME}
AV_RTSP_SERVER_PORT_RTSP=${AV_RTSP_SERVER_PORT_RTSP}
AV_RTSP_SERVER_FILE_LIST=${AV_RTSP_SERVER_FILE_LIST}
EOF
        
    fi
    readConfigurationFile "$configuration_file"
else
    printWarning "No env. file specified. Using environment variables."
fi

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
    if [ -f /workspace/.devcontainer/devcontainer.json ] 
    then
        checkDevContainerModeResult="1"
    fi
    echo $checkDevContainerModeResult
    return
}
# Create temporary directory
if [ ! -d "${AV_TEMPDIR}" ]
then
    mkdir "${AV_TEMPDIR}"
fi

if [ "${action}" = "install" ]
then
    printMessage "Installing pre-requisite"
    printProgress "Installing azure cli"
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    az config set extension.use_dynamic_install=yes_without_prompt
    sudo apt-get -y update
    sudo apt-get -y install  jq
    printProgress "Installing Typescript and node services "
    sudo npm install -g npm@latest 
    printProgress "NPM version:"
    sudo npm --version 
    sudo npm install --location=global -g typescript
    tsc --version
    sudo npm install --location=global -g webpack
    sudo npm install --location=global  --save-dev @types/jquery
    sudo npm install --location=global -g http-server
    sudo npm install --location=global -g forever
    printMessage "Installing pre-requisites done"
    exit 0
fi
if [ "${action}" = "login" ]
then
    printMessage "Login..."
    azLogin
    checkLoginAndSubscription
    printMessage "Login done"
    exit 0
fi


if [ "${action}" = "vmdeploy" ]
then
    printMessage "Deploying the infrastructure..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError    
    AZURE_RESOURCE_GROUP="rg$AZURE_PREFIX"
    PRE_DEPLOYMENT_NAME="PRE-$(date +"%y%m%d-%H%M%S")"
    printMessage "Deploy infrastructure subscription: '$AZURE_SUBSCRIPTION_ID' region: '$AZURE_REGION' resource group: '$AZURE_RESOURCE_GROUP'"
    cmd="az group create  --subscription $AZURE_SUBSCRIPTION_ID --location $AZURE_REGION --name $AZURE_RESOURCE_GROUP --output none "
    printProgress "$cmd"
    eval "$cmd"
    checkError

    cmd="az deployment group create \
        --name $PRE_DEPLOYMENT_NAME \
        --resource-group $AZURE_RESOURCE_GROUP \
        --subscription $AZURE_SUBSCRIPTION_ID \
        --template-file azuredeploy.json \
        --output none \
        --parameters \
        namePrefix=$AZURE_PREFIX computerVisionSku=$AZURE_COMPUTER_VISION_SKU customVisionSku=$AZURE_CUSTOM_VISION_SKU"
    printProgress "$cmd"
    eval "$cmd"
    checkError
    printMessage "Read result of the deployment"
    AZURE_STORAGE_ACCOUNT=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.storageAccount.value')
    AZURE_CONTENT_STORAGE_CONTAINER=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.contentContainer.value')
    AZURE_RECORD_STORAGE_CONTAINER=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.recordContainer.value')
    AZURE_RESULT_STORAGE_CONTAINER=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.resultContainer.value')
    AZURE_COMPUTER_VISION=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.computerVisionAccountName.value')
    AZURE_COMPUTER_VISION_KEY=\"$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.computerVisionKey.value')\"
    AZURE_COMPUTER_VISION_ENDPOINT=\"$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.computerVisionEndpoint.value')\"
    AZURE_CUSTOM_VISION_TRAINING=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.customVisionTrainingAccountName.value')
    AZURE_CUSTOM_VISION_TRAINING_KEY=\"$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.customVisionTrainingKey.value')\"
    AZURE_CUSTOM_VISION_TRAINING_ENDPOINT=\"$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.customVisionTrainingEndpoint.value')\"
    AZURE_CUSTOM_VISION_PREDICTION=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.customVisionPredictionAccountName.value')
    AZURE_CUSTOM_VISION_PREDICTION_KEY=\"$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.customVisionPredictionKey.value')\"
    AZURE_CUSTOM_VISION_PREDICTION_ENDPOINT=\"$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.customVisionPredictionEndpoint.value')\"
    AZURE_CONTAINER_REGISTRY=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.registryName.value')
    AZURE_ACR_LOGIN_SERVER=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$PRE_DEPLOYMENT_NAME" | jq -r '.properties.outputs.acrLoginServer.value')


    # Get current user objectId
    printProgress "Get current user objectId"
    UserType="User"
    UserSPMsiPrincipalId=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || true  
    if [ ! -n $UserSPMsiPrincipalId ]
    then
        printProgress "Get current service principal objectId"
        UserType="ServicePrincipal"
        # shellcheck disable=SC2154        
        UserSPMsiPrincipalId=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query id --output tsv  2> /dev/null) || true
    fi
    if [ -n $UserSPMsiPrincipalId ]
    then
        printProgress "Checking role assignment 'Azure Event Hubs Data Sender' between '${UserSPMsiPrincipalId}' and Storage Account  '${AZURE_STORAGE_ACCOUNT}'"
        UserSPMsiRoleAssignmentCount=$(az role assignment list --assignee "${UserSPMsiPrincipalId}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${AZURE_RESOURCE_GROUP}"/providers/Microsoft.Storage/storageAccounts/"${AZURE_STORAGE_ACCOUNT}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="Storage Blob Data Contributor") | length')

        if [ "$UserSPMsiRoleAssignmentCount" != "1" ];
        then
            printProgress  "Assigning 'Storage Blob Data Contributor' role assignment on scope '${AZURE_STORAGE_ACCOUNT}'..."
            cmd="az role assignment create --assignee-object-id \"$UserSPMsiPrincipalId\" --assignee-principal-type $UserType --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${AZURE_RESOURCE_GROUP}\"/providers/Microsoft.Storage/storageAccounts/\"${AZURE_STORAGE_ACCOUNT}\" --role \"Storage Blob Data Contributor\"  2>/dev/null"
            printProgress "$cmd"
            eval "$cmd"
            # Wait few seconds for role assignment 
            printProgress  "Waiting 90 seconds"
            sleep 90
        fi
    fi    
    printMessage "Creating SAS Tokens for Azure Storage Account ($AZURE_STORAGE_ACCOUNT)..."
    end=$(date -u -d "7 days" '+%Y-%m-%dT%H:%MZ')
    AZURE_CONTENT_STORAGE_CONTAINER_URL="https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_CONTENT_STORAGE_CONTAINER}"
    AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN="$(az storage container generate-sas --account-name "$AZURE_STORAGE_ACCOUNT"  --as-user  --auth-mode login  -n "$AZURE_CONTENT_STORAGE_CONTAINER" --https-only --permissions dlrw --expiry "$end" -o tsv)"

    AZURE_RECORD_STORAGE_CONTAINER_URL="https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_RECORD_STORAGE_CONTAINER}"
    AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN="$(az storage container generate-sas --account-name "$AZURE_STORAGE_ACCOUNT"  --as-user  --auth-mode login  -n "$AZURE_RECORD_STORAGE_CONTAINER" --https-only --permissions dlrw --expiry "$end" -o tsv)"

    AZURE_RESULT_STORAGE_CONTAINER_URL="https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_RESULT_STORAGE_CONTAINER}"
    AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN="$(az storage container generate-sas --account-name "$AZURE_STORAGE_ACCOUNT"  --as-user  --auth-mode login  -n "$AZURE_RESULT_STORAGE_CONTAINER" --https-only --permissions dlrw --expiry "$end" -o tsv)"
    printMessage "Create SAS Tokens for Azure Storage Account ($AZURE_STORAGE_ACCOUNT) done"

    
    printMessage "Upload files on Azure Storage Account $AZURE_STORAGE_ACCOUNT in container $AZURE_CONTENT_STORAGE_CONTAINER"
    installBashFile="evatool.sh"
    az storage blob upload --overwrite --no-progress --account-name "$AZURE_STORAGE_ACCOUNT"   --auth-mode login   --container-name "$AZURE_CONTENT_STORAGE_CONTAINER"  --file ./$installBashFile --name $installBashFile  --output none
    installBashUrl="https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$AZURE_CONTENT_STORAGE_CONTAINER/$installBashFile?$AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN"    
    printMessage "File: $installBashFile uploaded url: $installBashUrl"
    az storage blob upload --overwrite --no-progress --account-name "$AZURE_STORAGE_ACCOUNT"   --auth-mode login   --container-name "$AZURE_CONTENT_STORAGE_CONTAINER"  --file ./evatool.sh --name evatool.sh  --output none
    printMessage "File: evatool.sh uploaded"
    az storage blob upload --overwrite --no-progress --account-name "$AZURE_STORAGE_ACCOUNT"  --auth-mode login   --container-name "$AZURE_CONTENT_STORAGE_CONTAINER"  --file ${BASH_DIR}/../../../content/camera-300s.mkv --name camera-300s.mkv  --output none
    printMessage "File: camera-300s.mkv uploaded" 
    az storage blob upload --overwrite --no-progress --account-name "$AZURE_STORAGE_ACCOUNT"    --auth-mode login   --container-name "$AZURE_CONTENT_STORAGE_CONTAINER"  --file ${BASH_DIR}/../../../content/lots_015.mkv --name lots_015.mkv  --output none
    printMessage "File: lots_015.mkv uploaded"
    az storage blob upload --overwrite --no-progress --account-name "$AZURE_STORAGE_ACCOUNT"  --auth-mode login   --container-name "$AZURE_CONTENT_STORAGE_CONTAINER"  --file ${BASH_DIR}/../../../content/frame.jpg --name frame.jpg  --output none
    printMessage "File: frame.jpg uploaded"
    POST_DEPLOYMENT_NAME="POST-$(date +"%y%m%d-%H%M%S")"
     
    cmd="az deployment group create \
        --name $POST_DEPLOYMENT_NAME \
        --resource-group $AZURE_RESOURCE_GROUP \
        --subscription $AZURE_SUBSCRIPTION_ID \
        --template-file azuredeploy.vm.json \
        --output none \
        --parameters \
        namePrefix=$AZURE_PREFIX vmAdminUsername=$AZURE_LOGIN authenticationType=$AZURE_AUTHENTICATION_TYPE vmAdminPasswordOrKey=$AZURE_SSH_PUBLIC_KEY sshClientIPAddress=\"$AZURE_LOCAL_IP_ADDRESS\" vmSize=$AZURE_VM_SIZE installFileUri=\"$installBashUrl\" installFileName=$installBashFile portHTTP=$AZURE_PORT_HTTP portWebAppHTTP=$AZURE_PORT_WEBAPP_HTTP  portSSL=$AZURE_PORT_SSL portHLS=$AZURE_PORT_HLS portRTMP=$AZURE_PORT_RTMP portRTSP=$AZURE_PORT_RTSP lun=$LUN "             
    printProgress "$cmd"
    eval "$cmd"
    checkError
    AZURE_VIRTUAL_MACHINE_NAME=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$POST_DEPLOYMENT_NAME" | jq -r '.properties.outputs.virtualMachineName.value')
    AZURE_VIRTUAL_MACHINE_HOSTNAME=$(az deployment group show --resource-group "$AZURE_RESOURCE_GROUP" -n "$POST_DEPLOYMENT_NAME" | jq -r '.properties.outputs.virtualMachineHostname.value')

    printMessage "Grant Access to the Azure Container Registry ($AZURE_CONTAINER_REGISTRY) from the virtual Machine ($AZURE_VIRTUAL_MACHINE_NAME) role AcrPull"
    spID=$(az vm show --resource-group $AZURE_RESOURCE_GROUP --name $AZURE_VIRTUAL_MACHINE_NAME --query identity.principalId --out tsv)
    resourceID=$(az acr show --resource-group  $AZURE_RESOURCE_GROUP --name $AZURE_CONTAINER_REGISTRY --query id --output tsv)
    cmd="az role assignment create --assignee $spID --scope $resourceID --role acrpull"
    printProgress "$cmd"
    eval "$cmd"
    checkError

    printMessage "Grant Access to the Azure Storage Account ($AZURE_STORAGE_ACCOUNT) from the virtual Machine ($AZURE_VIRTUAL_MACHINE_NAME) role Storage Blob Data Contributor"
    spID=$(az vm show --resource-group $AZURE_RESOURCE_GROUP --name $AZURE_VIRTUAL_MACHINE_NAME --query identity.principalId --out tsv)
    resourceID=$(az storage account show --resource-group  $AZURE_RESOURCE_GROUP --name $AZURE_STORAGE_ACCOUNT --query id --output tsv)
    cmd="az role assignment create --assignee $spID --scope $resourceID --role 'Storage Blob Data Contributor'"
    printProgress "$cmd"
    eval "$cmd"
    checkError




    updateConfigurationFile "${configuration_file}" "AZURE_RESOURCE_GROUP" "${AZURE_RESOURCE_GROUP}"
    updateConfigurationFile "${configuration_file}" "AZURE_STORAGE_ACCOUNT" "${AZURE_STORAGE_ACCOUNT}"
    updateConfigurationFile "${configuration_file}" "AZURE_CONTENT_STORAGE_CONTAINER" "${AZURE_CONTENT_STORAGE_CONTAINER}"
    updateConfigurationFile "${configuration_file}" "AZURE_RECORD_STORAGE_CONTAINER" "${AZURE_RECORD_STORAGE_CONTAINER}"
    updateConfigurationFile "${configuration_file}" "AZURE_RESULT_STORAGE_CONTAINER" "${AZURE_RESULT_STORAGE_CONTAINER}"
    updateConfigurationFile "${configuration_file}" "AZURE_COMPUTER_VISION" "${AZURE_COMPUTER_VISION}"
    updateConfigurationFile "${configuration_file}" "AZURE_COMPUTER_VISION_KEY" "${AZURE_COMPUTER_VISION_KEY}"
    updateConfigurationFile "${configuration_file}" "AZURE_COMPUTER_VISION_ENDPOINT" "${AZURE_COMPUTER_VISION_ENDPOINT}"
    updateConfigurationFile "${configuration_file}" "AZURE_CUSTOM_VISION_TRAINING" "${AZURE_CUSTOM_VISION_TRAINING}"
    updateConfigurationFile "${configuration_file}" "AZURE_CUSTOM_VISION_TRAINING_KEY" "${AZURE_CUSTOM_VISION_TRAINING_KEY}"
    updateConfigurationFile "${configuration_file}" "AZURE_CUSTOM_VISION_TRAINING_ENDPOINT" "${AZURE_CUSTOM_VISION_TRAINING_ENDPOINT}"
    updateConfigurationFile "${configuration_file}" "AZURE_CUSTOM_VISION_PREDICTION" "${AZURE_CUSTOM_VISION_PREDICTION}"
    updateConfigurationFile "${configuration_file}" "AZURE_CUSTOM_VISION_PREDICTION_KEY" "${AZURE_CUSTOM_VISION_PREDICTION_KEY}"
    updateConfigurationFile "${configuration_file}" "AZURE_CUSTOM_VISION_PREDICTION_ENDPOINT" "${AZURE_CUSTOM_VISION_PREDICTION_ENDPOINT}"
    updateConfigurationFile "${configuration_file}" "AZURE_CONTAINER_REGISTRY" "${AZURE_CONTAINER_REGISTRY}"
    updateConfigurationFile "${configuration_file}" "AZURE_ACR_LOGIN_SERVER" "${AZURE_ACR_LOGIN_SERVER}"
    updateConfigurationFile "${configuration_file}" "AZURE_VIRTUAL_MACHINE_NAME" "${AZURE_VIRTUAL_MACHINE_NAME}"
    updateConfigurationFile "${configuration_file}" "AZURE_VIRTUAL_MACHINE_HOSTNAME" "${AZURE_VIRTUAL_MACHINE_HOSTNAME}"
    updateConfigurationFile "${configuration_file}" "AZURE_CONTENT_STORAGE_CONTAINER_URL" "${AZURE_CONTENT_STORAGE_CONTAINER_URL}"
    updateConfigurationFile "${configuration_file}" "AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN" "${AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN}"
    updateConfigurationFile "${configuration_file}" "AZURE_RECORD_STORAGE_CONTAINER_URL" "${AZURE_RECORD_STORAGE_CONTAINER_URL}"
    updateConfigurationFile "${configuration_file}" "AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN" "${AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN}"
    updateConfigurationFile "${configuration_file}" "AZURE_RESULT_STORAGE_CONTAINER_URL" "${AZURE_RESULT_STORAGE_CONTAINER_URL}"
    updateConfigurationFile "${configuration_file}" "AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN" "${AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN}"

    updateConfigurationFile "${configuration_file}" "AV_RECORDER_STORAGE_URL" "${AZURE_RECORD_STORAGE_CONTAINER_URL}"
    updateConfigurationFile "${configuration_file}" "AV_RECORDER_STORAGE_SAS_TOKEN" "${AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN}"
    updateConfigurationFile "${configuration_file}" "AV_EDGE_STORAGE_URL" "${AZURE_RESULT_STORAGE_CONTAINER_URL}"
    updateConfigurationFile "${configuration_file}" "AV_EDGE_STORAGE_SAS_TOKEN" "${AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN}"
    updateConfigurationFile "${configuration_file}" "AV_WEBAPP_STORAGE_RESULT_URL" "${AZURE_RESULT_STORAGE_CONTAINER_URL}"
    updateConfigurationFile "${configuration_file}" "AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN" "${AZURE_RESULT_STORAGE_CONTAINER_SAS_TOKEN}"
    updateConfigurationFile "${configuration_file}" "AV_WEBAPP_STORAGE_RECORD_URL" "${AZURE_RECORD_STORAGE_CONTAINER_URL}"
    updateConfigurationFile "${configuration_file}" "AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN" "${AZURE_RECORD_STORAGE_CONTAINER_SAS_TOKEN}"
    updateConfigurationFile "${configuration_file}" "AV_WEBAPP_STREAM_URL_PREFIX" "http://${AZURE_VIRTUAL_MACHINE_HOSTNAME}:${AV_RTMP_RTSP_PORT_HLS}/hls"
    updateConfigurationFile "${configuration_file}" "AV_RTMP_RTSP_HOSTNAME" "${AZURE_VIRTUAL_MACHINE_HOSTNAME}"

    updateConfigurationFile "${configuration_file}" "AV_MODEL_COMPUTER_VISION_URL" "${AZURE_COMPUTER_VISION_ENDPOINT}"
    updateConfigurationFile "${configuration_file}" "AV_MODEL_COMPUTER_VISION_KEY" "${AZURE_COMPUTER_VISION_KEY}"

    updateConfigurationFile "${configuration_file}" "AV_MODEL_CUSTOM_VISION_URL" "${AZURE_CUSTOM_VISION_PREDICTION_ENDPOINT}"
    updateConfigurationFile "${configuration_file}" "AV_MODEL_CUSTOM_VISION_KEY" "${AZURE_CUSTOM_VISION_PREDICTION_KEY}"

    printMessage "Upload configuration file ${configuration_file} in the virtual machine"
    az storage blob upload --overwrite --no-progress --account-name "$AZURE_STORAGE_ACCOUNT"   --auth-mode login   --container-name "$AZURE_CONTENT_STORAGE_CONTAINER"  --file "${configuration_file}" --name .avtoolconfig  --output none
    printMessage "File: .avtoolconfig uploaded"
    invokeRemoteCommand $AZURE_RESOURCE_GROUP $AZURE_VIRTUAL_MACHINE_NAME "curl -o /config/.avtoolconfig '$AZURE_CONTENT_STORAGE_CONTAINER_URL/.avtoolconfig?$AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN' "
    printMessage "Configuration file ${configuration_file} installed in the virtual machine"


    printMessage "Updating Azure Storage Account ($AZURE_STORAGE_ACCOUNT) CORS..."
    end=$(date -u -d "2 hours" '+%Y-%m-%dT%H:%MZ')
    AZURE_STORAGE_ACCOUNT_SAS_TOKEN="$(az storage account generate-sas --account-name "$AZURE_STORAGE_ACCOUNT"  --services b --resource-types sco  --https-only --permissions cdlruwap --expiry "$end" -o tsv)"

    cmd="az storage cors list --account-name ${AZURE_STORAGE_ACCOUNT}  --services b --sas-token \"${AZURE_STORAGE_ACCOUNT_SAS_TOKEN}\" | jq '.[].AllowedOrigins'"
    printProgress "$cmd"
    eval "$cmd"
    found="false"
    for input in $(eval "$cmd");
    do
        echo $input
        if [ "$input" = \"http://${AZURE_VIRTUAL_MACHINE_HOSTNAME}:${AZURE_PORT_WEBAPP_HTTP}\" ] 
        then
            found="true"
        fi
    done
    if [ "$found" = "false" ]
    then
        cmd="az storage cors add --account-name ${AZURE_STORAGE_ACCOUNT} --exposed-headers '*' --allowed-headers '*' --methods DELETE GET HEAD MERGE POST OPTIONS PUT PATCH --origins \"http://${AZURE_VIRTUAL_MACHINE_HOSTNAME}:${AZURE_PORT_WEBAPP_HTTP}\" --services b --max-age 3600 --sas-token \"${AZURE_STORAGE_ACCOUNT_SAS_TOKEN}\""
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        printProgress "CORS alreay added \"http://${AZURE_VIRTUAL_MACHINE_HOSTNAME}:${AZURE_PORT_WEBAPP_HTTP}\""
    fi
    printMessage "Updating Azure Storage Account ($AZURE_STORAGE_ACCOUNT) CORS done"

    printMessage "Deploying the infrastructure done"
    exit 0
fi

if [ "${action}" = "vmundeploy" ]
then
    printMessage "Undeploying the infrastructure..."
    # Check Azure connection
    printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
    azLogin
    checkError
    AZURE_RESOURCE_GROUP="rg$AZURE_PREFIX"
    cmd="az group delete  --subscription $AZURE_SUBSCRIPTION_ID  --name $AZURE_RESOURCE_GROUP -y --output none "
    printProgress "$cmd"
    eval "$cmd"

    printMessage "Undeploying the infrastructure done"
    exit 0
fi


if [ "${action}" = "vmbuild" ] || [ "${action}" = "build" ]
then
    printMessage "Building containers"
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
        azLogin
        checkError
        
        # Get current user objectId
        printProgress "Get current user objectId"
        UserType="User"
        UserSPMsiPrincipalId=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || true  
        if [ -z $UserSPMsiPrincipalId ] 
        then
            printProgress "Get current service principal objectId"
            UserType="ServicePrincipal"
            # shellcheck disable=SC2154        
            UserSPMsiPrincipalId=$(az ad sp show --id "$(az account show | jq -r .user.name)" --query id --output tsv  2> /dev/null) || true
        fi
        if [ -n $UserSPMsiPrincipalId ]
        then
            printProgress "Checking role assignment 'acrPull' between '${UserSPMsiPrincipalId}' and Storage Account  '${AZURE_CONTAINER_REGISTRY}'"
            UserSPMsiRoleAssignmentCount=$(az role assignment list --assignee "${UserSPMsiPrincipalId}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${AZURE_RESOURCE_GROUP}"/providers/Microsoft.ContainerRegistry/registries/"${AZURE_CONTAINER_REGISTRY}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="AcrPull") | length')

            if [ "$UserSPMsiRoleAssignmentCount" != "1" ]
            then
                printProgress  "Assigning 'acrPull' role assignment on scope '${AZURE_CONTAINER_REGISTRY}'..."
                cmd="az role assignment create --assignee-object-id \"$UserSPMsiPrincipalId\" --assignee-principal-type $UserType --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${AZURE_RESOURCE_GROUP}\"/providers/Microsoft.ContainerRegistry/registries/\"${AZURE_CONTAINER_REGISTRY}\" --role \"AcrPull\"  2>/dev/null"
                printProgress "$cmd"
                eval "$cmd"
                # Wait few seconds for role assignment 
                sleep 10
            fi
            printProgress "Checking role assignment 'acrPush' between '${UserSPMsiPrincipalId}' and Storage Account  '${AZURE_CONTAINER_REGISTRY}'"
            UserSPMsiRoleAssignmentCount=$(az role assignment list --assignee "${UserSPMsiPrincipalId}" --scope /subscriptions/"${AZURE_SUBSCRIPTION_ID}"/resourceGroups/"${AZURE_RESOURCE_GROUP}"/providers/Microsoft.ContainerRegistry/registries/"${AZURE_CONTAINER_REGISTRY}"   2>/dev/null | jq -r 'select(.[].roleDefinitionName=="AcrPush") | length')

            if [ "$UserSPMsiRoleAssignmentCount" != "1" ]
            then
                printProgress  "Assigning 'acrPush' role assignment on scope '${AZURE_CONTAINER_REGISTRY}'..."
                cmd="az role assignment create --assignee-object-id \"$UserSPMsiPrincipalId\" --assignee-principal-type $UserType --scope /subscriptions/\"${AZURE_SUBSCRIPTION_ID}\"/resourceGroups/\"${AZURE_RESOURCE_GROUP}\"/providers/Microsoft.ContainerRegistry/registries/\"${AZURE_CONTAINER_REGISTRY}\" --role \"AcrPush\"  2>/dev/null"
                printProgress "$cmd"
                eval "$cmd"
                # Wait few seconds for role assignment 
                sleep 10
            fi        
        fi    

        cmd="az acr login --name $AZURE_CONTAINER_REGISTRY"
        printProgress "$cmd"
        eval "$cmd"
    fi
    IMAGE_VERSION=$(date +"%y%m%d.%H%M%S")

    printProgress "Building container $AV_RTMP_RTSP_CONTAINER_NAME..."
    cmd="docker build  --build-arg  AV_RTMP_RTSP_PORT_RTSP=${AV_RTMP_RTSP_PORT_RTSP} --build-arg  AV_RTMP_RTSP_PORT_RTMP=${AV_RTMP_RTSP_PORT_RTMP} --build-arg  AV_RTMP_RTSP_PORT_SSL=${AV_RTMP_RTSP_PORT_SSL} --build-arg  AV_RTMP_RTSP_PORT_HTTP=${AV_RTMP_RTSP_PORT_HTTP} --build-arg  AV_RTMP_RTSP_PORT_HLS=${AV_RTMP_RTSP_PORT_HLS}  --build-arg  AV_RTMP_RTSP_HOSTNAME=${AV_RTMP_RTSP_HOSTNAME} --build-arg  AV_RTMP_RTSP_COMPANYNAME=${AV_RTMP_RTSP_COMPANYNAME} --build-arg  AV_RTMP_RTSP_STREAM_LIST=${AV_RTMP_RTSP_STREAM_LIST} -t ${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME}:${IMAGE_VERSION} ${BASH_DIR}/../docker/rtmprtspsink/ubuntu/." 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_RTMP_RTSP_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_RTMP_RTSP_CONTAINER_NAME done..."

    printProgress "Building container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    cmd="docker build -f ${BASH_DIR}/../docker/yolov3/http-cpu/yolov3.dockerfile ${BASH_DIR}/../docker/yolov3/http-cpu/. -t ${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_MODEL_YOLO_ONNX_IMAGE_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done..."

    printProgress "Building container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    cmd="docker build --build-arg  AV_MODEL_COMPUTER_VISION_PORT_HTTP=${AV_MODEL_COMPUTER_VISION_PORT_HTTP} -f ${BASH_DIR}/../docker/computervision/http-cpu/Dockerfile ${BASH_DIR}/../docker/computervision/http-cpu/. -t ${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done..."

    printProgress "Building container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    cmd="docker build --build-arg  AV_MODEL_CUSTOM_VISION_PORT_HTTP=${AV_MODEL_CUSTOM_VISION_PORT_HTTP} -f ${BASH_DIR}/../docker/customvision/http-cpu/Dockerfile ${BASH_DIR}/../docker/customvision/http-cpu/. -t ${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done..."

    printProgress "Building container $AV_EXTRACT_FRAME_CONTAINER_NAME..."
    cmd="docker build   -f ${BASH_DIR}/../docker/extractframe/ubuntu/Dockerfile ${BASH_DIR}/../docker/extractframe/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_EXTRACT_FRAME_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_EXTRACT_FRAME_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_EXTRACT_FRAME_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_EXTRACT_FRAME_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_EXTRACT_FRAME_CONTAINER_NAME done..."

    printProgress "Building container $AV_FFMPEG_CONTAINER_NAME..."
    cmd="docker build   -f ${BASH_DIR}/../docker/ffmpeg/ubuntu/Dockerfile ${BASH_DIR}/../docker/ffmpeg/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_FFMPEG_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_FFMPEG_CONTAINER_NAME done..."

    printProgress "Building container $AV_RECORDER_CONTAINER_NAME..."
    cmd="docker build   -f ${BASH_DIR}/../docker/recorder/ubuntu/Dockerfile ${BASH_DIR}/../docker/recorder/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_RECORDER_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_RECORDER_CONTAINER_NAME done..."

    printProgress "Building container $AV_EDGE_CONTAINER_NAME..."
    cmd="cp ${BASH_DIR}/../docker/extractframe/ubuntu/extractframe.c ${BASH_DIR}/../docker/avedge/ubuntu/" 
    printProgress "$cmd"
    eval "$cmd"
    cmd="docker build   -f ${BASH_DIR}/../docker/avedge/ubuntu/Dockerfile ${BASH_DIR}/../docker/avedge/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    cmd="rm  ${BASH_DIR}/../docker/avedge/ubuntu/extractframe.c" 
    printProgress "$cmd"
    eval "$cmd"
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_EDGE_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_EDGE_CONTAINER_NAME done..."

    printProgress "Building container $AV_WEBAPP_CONTAINER_NAME..."
    
    #pushd ${BASH_DIR}/../docker/webapp/ubuntu
    oldpath=`pwd`
    cd ${BASH_DIR}/../docker/webapp/ubuntu

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

    printProgress "Building the Web App Application"
    npm install
    npm audit fix || true
    tsc --build tsconfig.json
    webpack --config webpack.config.js
    
    #popd
    cd $oldpath

    printProgress "Building the Web App Container"
    cmd="docker build   -f ${BASH_DIR}/../docker/webapp/ubuntu/Dockerfile ${BASH_DIR}/../docker/webapp/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_WEBAPP_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    echo "Building container $AV_WEBAPP_CONTAINER_NAME done..."

    # printProgress "Building container $AV_RTSP_SOURCE_CONTAINER_NAME..."
    # cp ${BASH_DIR}/../../../content/camera-300s.mkv ${BASH_DIR}/../docker/rtspsource
    # cmd="docker build  -f ${BASH_DIR}/../docker/rtspsource/Dockerfile ${BASH_DIR}/../docker/rtspsource/. -t ${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME}:${IMAGE_VERSION}" 
    # printProgress "$cmd"
    # eval "$cmd"
    # checkError
    # rm ${BASH_DIR}/../docker/rtspsource/camera-300s.mkv
    # if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    # then
    #     printProgress "Pushing container $AV_RTSP_SOURCE_CONTAINER_NAME done..."
    #     pushImage  "${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    # else
    #     tagImage  "${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    # fi
    # printProgress "Building container $AV_RTSP_SOURCE_CONTAINER_NAME done..."

    printProgress "Building container $AV_RTSP_SERVER_CONTAINER_NAME..."
    cp ${BASH_DIR}/../../../content/camera-300s.mkv ${BASH_DIR}/../docker/rtspserver/ubuntu
    cmd="docker build  -f ${BASH_DIR}/../docker/rtspserver/ubuntu/Dockerfile ${BASH_DIR}/../docker/rtspserver/ubuntu/. -t ${AV_IMAGE_FOLDER}/${AV_RTSP_SERVER_IMAGE_NAME}:${IMAGE_VERSION}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    rm ${BASH_DIR}/../docker/rtspserver/ubuntu/camera-300s.mkv
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        printProgress "Pushing container $AV_RTSP_SERVER_CONTAINER_NAME done..."
        pushImage  "${AV_IMAGE_FOLDER}/${AV_RTSP_SERVER_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}" "${AZURE_ACR_LOGIN_SERVER}"
    else
        tagImage  "${AV_IMAGE_FOLDER}/${AV_RTSP_SERVER_IMAGE_NAME}" "${IMAGE_VERSION}" "${LATEST_IMAGE_VERSION}"
    fi
    printProgress "Building container $AV_RTSP_SERVER_CONTAINER_NAME done..."

    printMessage "${GREEN}Building container done${NC}"
    exit 0
fi

if [ "${action}" = "vmcreate" ]
then
    echo "Creating containers remotely..."    
    invokeRemoteCommand $AZURE_RESOURCE_GROUP $AZURE_VIRTUAL_MACHINE_NAME "az login --identity && az acr login -n $AZURE_CONTAINER_REGISTRY && /install/evatool.sh -a create -c /config/.avtoolconfig "
    echo "Creating containers remotely done..." 
    exit 0   
fi

if [ "${action}" = "vmremove" ]
then
    echo "Removing containers remotely..."    
    invokeRemoteCommand $AZURE_RESOURCE_GROUP $AZURE_VIRTUAL_MACHINE_NAME "az login --identity && az acr login -n $AZURE_CONTAINER_REGISTRY && /install/evatool.sh -a remove -c /config/.avtoolconfig "
    echo "Removing containers remotely done..." 
    exit 0   
fi

if [ "${action}" = "vmstop" ]
then
    echo "Stopping containers remotely..."    
    invokeRemoteCommand $AZURE_RESOURCE_GROUP $AZURE_VIRTUAL_MACHINE_NAME "az login --identity && az acr login -n $AZURE_CONTAINER_REGISTRY && /install/evatool.sh -a stop -c /config/.avtoolconfig "
    echo "Stopping containers remotely done..." 
    exit 0   
fi

if [ "${action}" = "vmstart" ]
then
    echo "Starting containers remotely..."    
    invokeRemoteCommand $AZURE_RESOURCE_GROUP $AZURE_VIRTUAL_MACHINE_NAME "az login --identity && az acr login -n $AZURE_CONTAINER_REGISTRY && /install/evatool.sh -a start -c /config/.avtoolconfig "
    echo "Starting containers remotely done..." 
    exit 0   
fi

if [ "${action}" = "vmstatus" ]
then
    echo "Getting Status containers remotely..."    
    invokeRemoteCommand $AZURE_RESOURCE_GROUP $AZURE_VIRTUAL_MACHINE_NAME "az login --identity && az acr login -n $AZURE_CONTAINER_REGISTRY && /install/evatool.sh -a status -c /config/.avtoolconfig "
    echo "Getting Status containers remotely done..." 
    exit 0   
fi

if [ "${action}" = "vmlogs" ]
then
    echo "Getting container logs remotely..."    
    invokeRemoteCommand $AZURE_RESOURCE_GROUP $AZURE_VIRTUAL_MACHINE_NAME "az login --identity && az acr login -n $AZURE_CONTAINER_REGISTRY && /install/evatool.sh -a logs -c /config/.avtoolconfig "
    echo "Getting container logs remotely done..." 
    exit 0   
fi



if [ "${action}" = "create" ]
then
    printMessage "Creating containers..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        cmd="az login --identity"
        printProgress "$cmd"
        eval "$cmd"
        checkError

        cmd="az acr login -n $AZURE_CONTAINER_REGISTRY "
        printProgress "$cmd"
        eval "$cmd"
        checkError

        printProgress "Copying Content file to shared volume..."
        for input in $(echo "${AV_FFMPEG_INPUT_LIST}" | tr "," "\n");
        do
            if [ $(getInputType "$input") = "file" ] || [ $(getInputType "$input") = "rtsp" ]
            then
                file=$(getInputFile "$input")
                cmd="curl \"https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$AZURE_CONTENT_STORAGE_CONTAINER/${file}?$AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN\" > /content/${file}"   
                printProgress "$cmd"
                eval "$cmd"
                checkError
            fi
        done
        # Copy the file camera-300s.mkv used to build rtsp-server and rtsp-source container 
        file="camera-300s.mkv"
        cmd="curl \"https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$AZURE_CONTENT_STORAGE_CONTAINER/${file}?$AZURE_CONTENT_STORAGE_CONTAINER_SAS_TOKEN\" > /content/${file}"   
        printProgress "$cmd"
        eval "$cmd"
        checkError                  
    else
        printProgress "Copying Content file to shared volume..."
        for input in $(echo "${AV_FFMPEG_INPUT_LIST}" | tr "," "\n");
        do
            if [ $(getInputType "$input") = "file" ]
            then
                file=$(getInputFile "$input")        
                cp ${BASH_DIR}/../../../content/${file} /content
            fi
        done
        # Copy the file camera-300s.mkv used to build rtsp-server and rtsp-source container 
        file="camera-300s.mkv"        
        cp ${BASH_DIR}/../../../content/${file} /content
    fi

    # printProgress "Creating and starting container $AV_RTSP_SOURCE_CONTAINER_NAME..."
    # if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    # then
    #     CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
    #     cmd="docker pull ${CONTAINER_IMAGE}"
    #     printProgress "$cmd"
    #     eval "$cmd"
    #     checkError
    # else
    #     CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_RTSP_SOURCE_IMAGE_NAME}"
    # fi
    # if [ $(checkDevContainerMode) = "1" ]
    # then
    #     TEMPVOL="content-volume"   
    # else
    #     TEMPVOL="/content"   
    # fi
    # cmd="docker run  -d -it  --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 -v ${TEMPVOL}:/live/mediaServer/media   -p ${AV_RTSP_SOURCE_PORT}:${AV_RTSP_SOURCE_PORT} -e RTSP_SOURCE_PORT=${AV_RTSP_SOURCE_PORT}  --name ${AV_RTSP_SOURCE_CONTAINER_NAME} ${CONTAINER_IMAGE}" 
    # printProgress "$cmd"
    # eval "$cmd"
    # checkError
    # printProgress "Creating and starting container $AV_RTSP_SOURCE_CONTAINER_NAME done"

    printProgress "Creating and starting container $AV_RTSP_SERVER_CONTAINER_NAME..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_RTSP_SERVER_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
        cmd="docker pull ${CONTAINER_IMAGE}"
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_RTSP_SERVER_IMAGE_NAME}"
    fi
    if [ $(checkDevContainerMode) = "1" ]
    then
        TEMPVOL="content-volume"   
    else
        TEMPVOL="/content"   
    fi
    cmd="docker run  -d -it  --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 -v ${TEMPVOL}:/live/mediaServer/media   -p ${AV_RTSP_SERVER_PORT_RTSP}:${AV_RTSP_SERVER_PORT_RTSP} -e PORT_RTSP=${AV_RTSP_SERVER_PORT_RTSP}  -e FILE_LIST=${AV_RTSP_SERVER_FILE_LIST} --name ${AV_RTSP_SERVER_CONTAINER_NAME} ${CONTAINER_IMAGE}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    printProgress "Creating and starting container $AV_RTSP_SERVER_CONTAINER_NAME done"




    printProgress "Creating and starting container $AV_RTMP_RTSP_CONTAINER_NAME..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
        cmd="docker pull ${CONTAINER_IMAGE}"
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_RTMP_RTSP_IMAGE_NAME}"
    fi
    cmd="docker run  -d -it --log-driver json-file --log-opt max-size=1m --log-opt max-file=3  -p ${AV_RTMP_RTSP_PORT_HTTP}:${AV_RTMP_RTSP_PORT_HTTP}/tcp  -p ${AV_RTMP_RTSP_PORT_HLS}:${AV_RTMP_RTSP_PORT_HLS}/tcp    -p ${AV_RTMP_RTSP_PORT_RTMP}:${AV_RTMP_RTSP_PORT_RTMP}/tcp -p ${AV_RTMP_RTSP_PORT_RTSP}:${AV_RTMP_RTSP_PORT_RTSP}/tcp  -p ${AV_RTMP_RTSP_PORT_SSL}:${AV_RTMP_RTSP_PORT_SSL}/tcp -e PORT_RTSP=${AV_RTMP_RTSP_PORT_RTSP} -e PORT_RTMP=${AV_RTMP_RTSP_PORT_RTMP} -e PORT_SSL=${AV_RTMP_RTSP_PORT_SSL} -e PORT_HTTP=${AV_RTMP_RTSP_PORT_HTTP} -e PORT_HLS=${AV_RTMP_RTSP_PORT_HLS}  -e HOSTNAME=${AV_RTMP_RTSP_HOSTNAME} -e COMPANYNAME=${AV_RTMP_RTSP_COMPANYNAME} -e  STREAM_LIST=${AV_RTMP_RTSP_STREAM_LIST} --name ${AV_RTMP_RTSP_CONTAINER_NAME} ${CONTAINER_IMAGE}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    printProgress "Creating and starting container $AV_RTMP_RTSP_CONTAINER_NAME done"


    printProgress "Creating and starting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
        cmd="docker pull ${CONTAINER_IMAGE}"
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_MODEL_YOLO_ONNX_IMAGE_NAME}"
    fi
    cmd="docker run --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 --name ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} -p ${AV_MODEL_YOLO_ONNX_PORT_HTTP}:${AV_MODEL_YOLO_ONNX_PORT_HTTP}/tcp -d  -i ${CONTAINER_IMAGE}"
    printProgress "$cmd"
    eval "$cmd"
    checkError
    printProgress "Creating and starting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done"
    
    printProgress "Creating and starting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
        cmd="docker pull ${CONTAINER_IMAGE}"
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_MODEL_COMPUTER_VISION_IMAGE_NAME}"
    fi
    cmd="docker run --log-driver json-file --log-opt max-size=1m --log-opt max-file=3  --name ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} -e COMPUTER_VISION_URL=${AV_MODEL_COMPUTER_VISION_URL} -e COMPUTER_VISION_KEY=${AV_MODEL_COMPUTER_VISION_KEY} -p ${AV_MODEL_COMPUTER_VISION_PORT_HTTP}:${AV_MODEL_COMPUTER_VISION_PORT_HTTP}/tcp -d  -i ${CONTAINER_IMAGE}"
    printProgress "$cmd"
    eval "$cmd"
    checkError
    printProgress "Creating and starting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done"


    # printProgress "Creating and starting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    # if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    # then
    #     CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
    #     cmd="docker pull ${CONTAINER_IMAGE}"
    #     printProgress "$cmd"
    #     eval "$cmd"
    #     checkError
    # else
    #     CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_MODEL_CUSTOM_VISION_IMAGE_NAME}"
    # fi
    # cmd="docker run  --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 --name ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} -e CUSTOM_VISION_URL=${AV_MODEL_CUSTOM_VISION_URL} -e CUSTOM_VISION_KEY=${AV_MODEL_CUSTOM_VISION_KEY} -p ${AV_MODEL_CUSTOM_VISION_PORT_HTTP}:${AV_MODEL_CUSTOM_VISION_PORT_HTTP}/tcp -d  -i ${CONTAINER_IMAGE}"
    # printProgress "$cmd"
    # eval "$cmd"
    # checkError
    # printProgress "Creating and starting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done"

    printProgress "Creating and starting container(s) $AV_FFMPEG_CONTAINER_NAME..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
        cmd="docker pull ${CONTAINER_IMAGE}"
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_FFMPEG_IMAGE_NAME}"
    fi
    CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
    if [ $(checkDevContainerMode) = "1" ]
    then
        docker network connect spikes_devcontainer_default ${AV_RTMP_RTSP_CONTAINER_NAME}  2> /dev/null || true  
        TEMPVOL="content-volume"   
    else
        CONTAINER_IP=${AV_RTMP_RTSP_HOSTNAME}
        TEMPVOL="/content"   
    fi
    if [ $(echo ${AV_FFMPEG_VOLUME} | cut -b1) != "/" ]
    then
        AV_FFMPEG_VOLUME="/${AV_FFMPEG_VOLUME}"
    fi
    printProgress "RTMP server IP Address: ${CONTAINER_RTMP_SERVER_IP}"
    printProgress "TEMPVOL: ${TEMPVOL}"    

    CONTAINER_RTSP_SERVER_IP=$(docker container inspect "${AV_RTSP_SERVER_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
    fileIndex=0
    for input in $(echo "${AV_FFMPEG_INPUT_LIST}" | tr "," "\n");
    do
        streamIndex=0
        type=$(getInputType "$input")
        file=$(getInputFile "$input")

        if [ "$type" = "file" ] || [ "$type" = "rtsp" ]
        then
            inputurl=""
            if [ "$type" = "file" ]
            then
                inputurl="${AV_FFMPEG_VOLUME}/${file}"
            fi
            if [ "$type" = "rtsp" ]
            then
                inputurl="rtsp://${CONTAINER_RTSP_SERVER_IP}:${AV_RTSP_SERVER_PORT_RTSP}/media/${file}"
            fi

            for stream in $(echo "${AV_FFMPEG_STREAM_LIST}" | tr "," "\n")
            do
                if [ "$streamIndex" = "$fileIndex" ]
                then
                    printProgress "Creating and starting container(s) ${AV_FFMPEG_CONTAINER_NAME}-${stream}..."
                    cmd="docker run    -d -it --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 -v ${TEMPVOL}:${AV_FFMPEG_VOLUME} --name \"${AV_FFMPEG_CONTAINER_NAME}-${stream}\" --restart always ${CONTAINER_IMAGE} ffmpeg -hide_banner -loglevel error  -re -stream_loop -1  -use_wallclock_as_timestamps 1 -rtsp_transport tcp -i ${inputurl} -codec copy  -f flv rtmp://${CONTAINER_RTMP_SERVER_IP}:${AV_RTMP_RTSP_PORT_RTMP}/live/${stream}"
                    printProgress "$cmd"
                    eval "$cmd"
                    checkError
                    printProgress "Creating and starting container(s) ${AV_FFMPEG_CONTAINER_NAME}-${stream} done..."
                fi
                streamIndex=$((streamIndex+1))
            done
        fi
        fileIndex=$((fileIndex+1))
    done

    printProgress "Creating and starting container(s) $AV_RECORDER_CONTAINER_NAME..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
        cmd="docker pull ${CONTAINER_IMAGE}"
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_RECORDER_IMAGE_NAME}"
    fi
    CONTAINER_RTSP_SERVER_IP=$(docker container inspect "${AV_RTSP_SERVER_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
    CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
    if [ $(checkDevContainerMode) = "1" ]
    then
        docker network connect spikes_devcontainer_default ${AV_RTMP_RTSP_CONTAINER_NAME}  2> /dev/null || true  
        #DEV_CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        #CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
        TEMPVOL="content-volume"   
    else
        CONTAINER_IP=${AV_RTMP_RTSP_HOSTNAME}
        #TEMPVOL=${AV_TEMPDIR}  
        TEMPVOL="/content"   
 
    fi    
    if [ $(echo ${AV_RECORDER_VOLUME} | cut -b1) != "/" ]
    then
        AV_RECORDER_VOLUME="/${AV_RECORDER_VOLUME}"
    fi
    fileIndex=0
    for input in $(echo "${AV_FFMPEG_INPUT_LIST}" | tr "," "\n");
    do
        streamIndex=0
        type=$(getInputType "$input")
        file=$(getInputFile "$input")

        if [ "$type" = "file" ] || [ "$type" = "rtsp" ]
        then
            for stream in $(echo "${AV_RECORDER_STREAM_LIST}" | tr "," "\n")
            do
                if [ "$streamIndex" = "$fileIndex" ]
                then
                    printProgress "Creating and starting container ${AV_RECORDER_CONTAINER_NAME}-${stream}..."
                    #cmd="docker run    -d -it  --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 -v ${TEMPVOL}:${AV_RECORDER_VOLUME} -e INPUT_URL=\"rtmp://${CONTAINER_RTMP_SERVER_IP}:${AV_RTMP_RTSP_PORT_RTMP}/live/${stream}\" -e  PERIOD=\"${AV_RECORDER_PERIOD}\"  -e  STORAGE_URL=\"${AV_RECORDER_STORAGE_URL}\"   -e  STORAGE_SAS_TOKEN=\"${AV_RECORDER_STORAGE_SAS_TOKEN}\"  -e  STORAGE_FOLDER=\"${AV_RECORDER_STORAGE_FOLDER}/${stream}\"   --name ${AV_RECORDER_CONTAINER_NAME}-${stream} ${CONTAINER_IMAGE} "
                    cmd="docker run    -d -it --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 -v ${TEMPVOL}:${AV_RECORDER_VOLUME} -e INPUT_URL=\"rtsp://${CONTAINER_RTSP_SERVER_IP}:${AV_RTSP_SERVER_PORT_RTSP}/media/${file}\" -e  PERIOD=\"${AV_RECORDER_PERIOD}\"  -e  STORAGE_URL=\"${AV_RECORDER_STORAGE_URL}\"   -e  STORAGE_SAS_TOKEN=\"${AV_RECORDER_STORAGE_SAS_TOKEN}\"  -e  STORAGE_FOLDER=\"${AV_RECORDER_STORAGE_FOLDER}/${stream}\"   --name ${AV_RECORDER_CONTAINER_NAME}-${stream} ${CONTAINER_IMAGE} "

                    printProgress "$cmd"
                    eval "$cmd"
                    checkError
                    printProgress "Creating and starting container ${AV_RECORDER_CONTAINER_NAME}-${stream} done"
                fi
                streamIndex=$((streamIndex+1))
            done
        fi
        fileIndex=$((fileIndex+1))
    done    
    printProgress "Creating and starting container $AV_RECORDER_CONTAINER_NAME done"

    printProgress "Creating and starting container(s) $AV_EDGE_CONTAINER_NAME..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
        cmd="docker pull ${CONTAINER_IMAGE}"
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_EDGE_IMAGE_NAME}"
    fi
    CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
    CONTAINER_RTSP_SERVER_IP=$(docker container inspect "${AV_RTSP_SERVER_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')

    CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
    CONTAINER_MODEL_PORT_HTTP=$AV_MODEL_YOLO_ONNX_PORT_HTTP
    #CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
    #CONTAINER_MODEL_PORT_HTTP=$AV_MODEL_COMPUTER_VISION_PORT_HTTP
    #CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')
    #CONTAINER_MODEL_PORT_HTTP=$AV_MODEL_CUSTOM_VISION_PORT_HTTP

    if [ $(checkDevContainerMode) = "1" ]
    then
        docker network connect spikes_devcontainer_default ${AV_RTMP_RTSP_CONTAINER_NAME}  2> /dev/null || true  
        #DEV_CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        #CONTAINER_RTMP_SERVER_IP=$(docker container inspect "${AV_RTMP_RTSP_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress')

        docker network connect spikes_devcontainer_default ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}  2> /dev/null || true  
        #DEV_CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        
        #docker network connect spikes_devcontainer_default ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}  2> /dev/null || true  
        #DEV_CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')

        #docker network connect spikes_devcontainer_default ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}  2> /dev/null || true  
        #DEV_CONTAINER_MODEL_SERVER_IP=$(docker container inspect "${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}" | jq -r '.[].NetworkSettings.Networks."spikes_devcontainer_default".IPAddress')
        TEMPVOL="content-volume"   
    else
        CONTAINER_IP=${AV_RTMP_RTSP_HOSTNAME}
        #TEMPVOL=${AV_TEMPDIR}
        TEMPVOL="/content"   
   
    fi    
    #if [ ${AV_EDGE_VOLUME::1} != "/" ]
    if [ $(echo ${AV_EDGE_VOLUME} | cut -b1) != "/" ]    
    then
        AV_EDGE_VOLUME="/${AV_EDGE_VOLUME}"
    fi
    #for stream in $(echo "${AV_EDGE_STREAM_LIST}" | tr "," "\n")
    #do
    fileIndex=0
    for input in $(echo "${AV_FFMPEG_INPUT_LIST}" | tr "," "\n");
    do
        streamIndex=0
        type=$(getInputType "$input")
        file=$(getInputFile "$input")
        frame=$(getInputFrame "$input")
        AV_WAIT_START_FRAME="0"
        AV_WAIT_KEY_FRAME="0"
        if [ "$frame" = "kframe" ]
        then
            AV_WAIT_KEY_FRAME="1"
        elif [ "$frame" = "sframe" ]
        then
            AV_WAIT_START_FRAME="1"
        else
            AV_WAIT_START_FRAME="0"
            AV_WAIT_KEY_FRAME="0"
        fi

        if [ "$type" = "file" ] || [ "$type" = "rtsp" ]
        then
            for stream in $(echo "${AV_RECORDER_STREAM_LIST}" | tr "," "\n")
            do
                if [ "$streamIndex" = "$fileIndex" ]
                then
                    printProgress "Creating and starting container ${AV_EDGE_CONTAINER_NAME}-${stream}..."
                    #cmd="docker run   -d -it --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 -v ${TEMPVOL}:${AV_EDGE_VOLUME} -e MODEL_URL=\"http://${CONTAINER_MODEL_SERVER_IP}:${CONTAINER_MODEL_PORT_HTTP}/score\" -e INPUT_URL=\"rtmp://${CONTAINER_RTMP_SERVER_IP}:${AV_RTMP_RTSP_PORT_RTMP}/live/${stream}\" -e  PERIOD=\"${AV_EDGE_PERIOD}\"  -e  STORAGE_URL=\"${AV_EDGE_STORAGE_URL}\"   -e  STORAGE_SAS_TOKEN=\"${AV_EDGE_STORAGE_SAS_TOKEN}\"  -e  STORAGE_FOLDER=\"${AV_EDGE_STORAGE_FOLDER}/${stream}\"   --name \"${AV_EDGE_CONTAINER_NAME}-${stream}\" ${CONTAINER_IMAGE} "
                    cmd="docker run   -d -it --log-driver json-file --log-opt max-size=1m --log-opt max-file=3 -v ${TEMPVOL}:${AV_EDGE_VOLUME} -e MODEL_URL=\"http://${CONTAINER_MODEL_SERVER_IP}:${CONTAINER_MODEL_PORT_HTTP}/score\" -e WAIT_START_FRAME=\"${AV_WAIT_START_FRAME}\" -e WAIT_KEY_FRAME=\"${AV_WAIT_KEY_FRAME}\" -e INPUT_URL=\"rtsp://${CONTAINER_RTSP_SERVER_IP}:${AV_RTSP_SERVER_PORT_RTSP}/media/${file}\" -e  PERIOD=\"${AV_EDGE_PERIOD}\"  -e  STORAGE_URL=\"${AV_EDGE_STORAGE_URL}\"   -e  STORAGE_SAS_TOKEN=\"${AV_EDGE_STORAGE_SAS_TOKEN}\"  -e  STORAGE_FOLDER=\"${AV_EDGE_STORAGE_FOLDER}/${stream}\"   --name \"${AV_EDGE_CONTAINER_NAME}-${stream}\" ${CONTAINER_IMAGE} "
                    printProgress "$cmd"
                    eval "$cmd"
                    checkError
                    printProgress "Creating and starting container ${AV_EDGE_CONTAINER_NAME}-${stream} done"
                fi
                streamIndex=$((streamIndex+1))
            done
        fi
        fileIndex=$((fileIndex+1))
    done  
    printProgress "Creating and starting container(s) $AV_EDGE_CONTAINER_NAME done"

    printProgress "Creating and starting container $AV_WEBAPP_CONTAINER_NAME..."
    if [ -n "${AZURE_CONTAINER_REGISTRY}" ]
    then
        CONTAINER_IMAGE="${AZURE_ACR_LOGIN_SERVER}/${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME}:${LATEST_IMAGE_VERSION}"
        cmd="docker pull ${CONTAINER_IMAGE}"
        printProgress "$cmd"
        eval "$cmd"
        checkError
    else
        CONTAINER_IMAGE="${AV_IMAGE_FOLDER}/${AV_WEBAPP_IMAGE_NAME}"
    fi
    cmd="docker run  -d -it  --log-driver json-file --log-opt max-size=1m --log-opt max-file=3  -p ${AV_WEBAPP_PORT_HTTP}:${AV_WEBAPP_PORT_HTTP}/tcp  -e WEBAPP_PORT_HTTP=${AV_WEBAPP_PORT_HTTP} -e  WEBAPP_STORAGE_RESULT_URL=\"${AV_WEBAPP_STORAGE_RESULT_URL}\"   -e  WEBAPP_STORAGE_RESULT_SAS_TOKEN=\"${AV_WEBAPP_STORAGE_RESULT_SAS_TOKEN}\" -e  WEBAPP_STORAGE_RECORD_URL=\"${AV_WEBAPP_STORAGE_RECORD_URL}\"   -e  WEBAPP_STORAGE_RECORD_SAS_TOKEN=\"${AV_WEBAPP_STORAGE_RECORD_SAS_TOKEN}\" -e WEBAPP_STREAM_URL_PREFIX=\"http://${AZURE_VIRTUAL_MACHINE_HOSTNAME}:${AV_RTMP_RTSP_PORT_HLS}/hls\"  --name ${AV_WEBAPP_CONTAINER_NAME} ${CONTAINER_IMAGE}" 
    printProgress "$cmd"
    eval "$cmd"
    checkError
    printProgress "Creating and starting container $AV_WEBAPP_CONTAINER_NAME done"



    printMessage "${GREEN}Deployment done${NC}"
    exit 0
fi

if [ "${action}" = "remove" ]
then
    printMessage "Removing containers..."
    
    printProgress "Removing container(s) $AV_RECORDER_CONTAINER_NAME..."
    for stream in $(echo "${AV_RECORDER_STREAM_LIST}" | tr "," "\n")
    do
        printProgress "Removing container ${AV_RECORDER_CONTAINER_NAME}-${stream}..."
        docker container stop ${AV_RECORDER_CONTAINER_NAME}-${stream} > /dev/null 2> /dev/null  || true
        docker container rm ${AV_RECORDER_CONTAINER_NAME}-${stream} > /dev/null 2> /dev/null  || true
        printProgress "Removing container ${AV_RECORDER_CONTAINER_NAME}-${stream} done"
    done    
    printProgress "Removing container(s) $AV_RECORDER_CONTAINER_NAME done"

    printProgress "Removing container(s) $AV_EDGE_CONTAINER_NAME..."
    for stream in $(echo "${AV_EDGE_STREAM_LIST}" | tr "," "\n")
    do
        printProgress "Removing container ${AV_EDGE_CONTAINER_NAME}-${stream}..."
        docker container stop ${AV_EDGE_CONTAINER_NAME}-${stream} > /dev/null 2> /dev/null  || true
        docker container rm ${AV_EDGE_CONTAINER_NAME}-${stream} > /dev/null 2> /dev/null  || true
        printProgress "Removing container ${AV_EDGE_CONTAINER_NAME}-${stream} done"
    done  
    printProgress "Removing container(s) $AV_EDGE_CONTAINER_NAME done"

    printProgress "Removing container $AV_RTMP_RTSP_CONTAINER_NAME..."
    docker container stop ${AV_RTMP_RTSP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_RTMP_RTSP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    printProgress "Removing container $AV_RTMP_RTSP_CONTAINER_NAME done"

    printProgress "Removing container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    docker container stop ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    printProgress "Removing container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done"

    printProgress "Removing container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    docker container stop ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    printProgress "Removing container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done"

    # printProgress "Removing container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    # docker container stop ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    # docker container rm ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    # printProgress "Removing container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done"

    printProgress "Removing container(s) $AV_FFMPEG_CONTAINER_NAME..."
    for stream in $(echo "${AV_FFMPEG_STREAM_LIST}" | tr "," "\n")
    do
        printProgress "Stopping and removing container(s) ${AV_FFMPEG_CONTAINER_NAME}-${stream}..."
        docker container stop "${AV_FFMPEG_CONTAINER_NAME}-${stream}" > /dev/null 2> /dev/null  || true
        docker container rm "${AV_FFMPEG_CONTAINER_NAME}-${stream}" > /dev/null 2> /dev/null  || true
        printProgress "Stopping and removing container(s) ${AV_FFMPEG_CONTAINER_NAME}-${stream} done..."
    done    
    printProgress "Removing container(s) $AV_FFMPEG_CONTAINER_NAME done"

    printProgress "Removing container $AV_WEBAPP_CONTAINER_NAME..."
    docker container stop ${AV_WEBAPP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_WEBAPP_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    printProgress "Removing container $AV_WEBAPP_CONTAINER_NAME done"

    # printProgress "Removing container $AV_RTSP_SOURCE_CONTAINER_NAME..."
    # docker container stop ${AV_RTSP_SOURCE_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    # docker container rm ${AV_RTSP_SOURCE_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    # printProgress "Removing container $AV_RTSP_SOURCE_CONTAINER_NAME done"

    printProgress "Removing container $AV_RTSP_SERVER_CONTAINER_NAME..."
    docker container stop ${AV_RTSP_SERVER_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    docker container rm ${AV_RTSP_SERVER_CONTAINER_NAME} > /dev/null 2> /dev/null  || true
    printProgress "Removing container $AV_RTSP_SERVER_CONTAINER_NAME done"


    printMessage "${GREEN}Undeployment done${NC}"
    exit 0
fi

if [ "${action}" = "status" ]
then
    printMessage "Checking containers status..."

    printProgress "Getting container $AV_RTMP_RTSP_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_RTMP_RTSP_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd" || true
    printProgress "Getting container $AV_RTMP_RTSP_CONTAINER_NAME status done"

    printProgress "Getting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd" || true
    printProgress "Getting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME status done"

    printProgress "Getting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd" || true
    printProgress "Getting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME status done"

    # printProgress "Getting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME status..."
    # cmd="docker container inspect ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME} --format '{{json .State.Status}}'"
    # eval "$cmd" || true
    # printProgress "Getting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME status done"

    printProgress "Getting container(s) $AV_FFMPEG_CONTAINER_NAME status..."
    for stream in $(echo "${AV_FFMPEG_STREAM_LIST}" | tr "," "\n")    
    do
        printProgress "Getting container ${AV_FFMPEG_CONTAINER_NAME}-${stream} status..."
        cmd="docker container inspect \"${AV_FFMPEG_CONTAINER_NAME}-${stream}\" --format '{{json .State.Status}}'"
        eval "$cmd" || true
    done    
    printProgress "Getting container(s) $AV_FFMPEG_CONTAINER_NAME status done"

    printProgress "Getting container(s) $AV_RECORDER_CONTAINER_NAME status..."
    for stream in $(echo "${AV_RECORDER_STREAM_LIST}" | tr "," "\n") 
    do
        printProgress "Getting container ${AV_RECORDER_CONTAINER_NAME}-${stream} status..."
        cmd="docker container inspect ${AV_RECORDER_CONTAINER_NAME}-${stream} --format '{{json .State.Status}}'"
        eval "$cmd" || true
        printProgress "Getting container ${AV_RECORDER_CONTAINER_NAME}-${stream} status done"
    done    
    printProgress "Getting container(s) $AV_RECORDER_CONTAINER_NAME status done"

    printProgress "Getting container(s) $AV_EDGE_CONTAINER_NAME status..."
    for stream in $(echo "${AV_EDGE_STREAM_LIST}" | tr "," "\n") 
    do
        printProgress "Getting container ${AV_EDGE_CONTAINER_NAME}-${stream} status..."
        cmd="docker container inspect ${AV_EDGE_CONTAINER_NAME}-${stream} --format '{{json .State.Status}}'"
        eval "$cmd" || true
        printProgress "Getting container ${AV_EDGE_CONTAINER_NAME}-${stream} status done"
    done    
    printProgress "Getting container $AV_EDGE_CONTAINER_NAME status done"

    printProgress "Getting container $AV_WEBAPP_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_WEBAPP_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd" || true
    printProgress "Getting container $AV_WEBAPP_CONTAINER_NAME status done"

    # printProgress "Getting container $AV_RTSP_SOURCE_CONTAINER_NAME status..."
    # cmd="docker container inspect ${AV_RTSP_SOURCE_CONTAINER_NAME} --format '{{json .State.Status}}'"
    # eval "$cmd" || true
    # printProgress "Getting container $AV_RTSP_SOURCE_CONTAINER_NAME status done"

    printProgress "Getting container $AV_RTSP_SERVER_CONTAINER_NAME status..."
    cmd="docker container inspect ${AV_RTSP_SERVER_CONTAINER_NAME} --format '{{json .State.Status}}'"
    eval "$cmd" || true
    printProgress "Getting container $AV_RTSP_SERVER_CONTAINER_NAME status done"

    printMessage "${GREEN}Container status done${NC}"
    exit 0
fi

if [ "${action}" = "logs" ]
then
    printMessage "Getting containers logs..."

    printProgress "Getting container $AV_RTMP_RTSP_CONTAINER_NAME logs..."
    cmd="docker logs ${AV_RTMP_RTSP_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Getting container $AV_RTMP_RTSP_CONTAINER_NAME logs done"

    printProgress "Getting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME logs..."
    cmd="docker logs ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Getting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME logs done"

    printProgress "Getting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME logs..."
    cmd="docker logs ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Getting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME logs done"

    # printProgress "Getting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME logs..."
    # cmd="docker logs ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}"
    # eval "$cmd" || true
    # printProgress "Getting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME logs done"

    printProgress "Getting container(s) $AV_FFMPEG_CONTAINER_NAME logs..."
    for stream in $(echo "${AV_FFMPEG_STREAM_LIST}" | tr "," "\n")    
    do
        printProgress "Getting container ${AV_FFMPEG_CONTAINER_NAME}-${stream} status..."
        cmd="docker container inspect \"${AV_FFMPEG_CONTAINER_NAME}-${stream}\""
        eval "$cmd" || true
    done    
    printProgress "Getting container(s) $AV_FFMPEG_CONTAINER_NAME logs done"

    printProgress "Getting container(s) $AV_RECORDER_CONTAINER_NAME logs..."
    for stream in $(echo "${AV_RECORDER_STREAM_LIST}" | tr "," "\n") 
    do
        printProgress "Getting container ${AV_RECORDER_CONTAINER_NAME}-${stream} status..."
        cmd="docker logs ${AV_RECORDER_CONTAINER_NAME}-${stream}"
        eval "$cmd" || true
        printProgress "Getting container ${AV_RECORDER_CONTAINER_NAME}-${stream} status done"
    done    
    printProgress "Getting container(s) $AV_RECORDER_CONTAINER_NAME logs done"

    printProgress "Getting container(s) $AV_EDGE_CONTAINER_NAME logs..."
    for stream in $(echo "${AV_EDGE_STREAM_LIST}" | tr "," "\n") 
    do
        printProgress "Getting container ${AV_EDGE_CONTAINER_NAME}-${stream} status..."
        cmd="docker logs ${AV_EDGE_CONTAINER_NAME}-${stream}"
        eval "$cmd" || true
        printProgress "Getting container ${AV_EDGE_CONTAINER_NAME}-${stream} status done"
    done    
    printProgress "Getting container $AV_EDGE_CONTAINER_NAME logs done"

    printProgress "Getting container $AV_WEBAPP_CONTAINER_NAME logs..."
    cmd="docker logs ${AV_WEBAPP_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Getting container $AV_WEBAPP_CONTAINER_NAME logs done"

    # printProgress "Getting container $AV_RTSP_SOURCE_CONTAINER_NAME logs..."
    # cmd="docker logs ${AV_RTSP_SOURCE_CONTAINER_NAME}"
    # eval "$cmd" || true
    # printProgress "Getting container $AV_RTSP_SOURCE_CONTAINER_NAME logs done"

    printProgress "Getting container $AV_RTSP_SERVER_CONTAINER_NAME logs..."
    cmd="docker logs ${AV_RTSP_SERVER_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Getting container $AV_RTSP_SERVER_CONTAINER_NAME logs done"

    printMessage "${GREEN}Container status done${NC}"
    exit 0
fi

if [ "${action}" = "start" ]
then
    printMessage "Starting containers..."

    # printProgress "Starting container $AV_RTSP_SOURCE_CONTAINER_NAME..."
    # cmd="docker container start ${AV_RTSP_SOURCE_CONTAINER_NAME}"
    # eval "$cmd"
    # checkError
    # printProgress "Starting container $AV_RTSP_SOURCE_CONTAINER_NAME done"

    printProgress "Starting container $AV_RTSP_SERVER_CONTAINER_NAME..."
    cmd="docker container start ${AV_RTSP_SERVER_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    printProgress "Starting container $AV_RTSP_SERVER_CONTAINER_NAME done"

    printProgress "Starting container $AV_RTMP_RTSP_CONTAINER_NAME..."
    cmd="docker container start ${AV_RTMP_RTSP_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    printProgress "Starting container $AV_RTMP_RTSP_CONTAINER_NAME done"


    printProgress "Starting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    cmd="docker container start ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    printProgress "Starting container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done"

    printProgress "Starting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    cmd="docker container start ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    printProgress "Starting container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done"

    # printProgress "Starting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    # cmd="docker container start ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}"
    # eval "$cmd"
    # checkError
    # printProgress "Starting container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done"

    printProgress "Starting container(s) $AV_FFMPEG_CONTAINER_NAME..."
    #streamArray=(${AV_FFMPEG_STREAM_LIST//:/ })
    #for i in "${!streamArray[@]}"
    for stream in $(echo "${AV_FFMPEG_STREAM_LIST}" | tr "," "\n")    
    do
        printProgress "Starting container ${AV_FFMPEG_CONTAINER_NAME}-${stream}..."
        cmd="docker container start \"${AV_FFMPEG_CONTAINER_NAME}-${stream}\""
        eval "$cmd"
        checkError
    done    
    printProgress "Starting container(s) $AV_FFMPEG_CONTAINER_NAME done"

    printProgress "Starting container(s) $AV_RECORDER_CONTAINER_NAME..."
    for stream in $(echo "${AV_RECORDER_STREAM_LIST}" | tr "," "\n")    
    do
        printProgress "Starting container ${AV_RECORDER_CONTAINER_NAME}-${stream}..."
        cmd="docker container start ${AV_RECORDER_CONTAINER_NAME}-${stream}"
        eval "$cmd"
        checkError
        printProgress "Starting container ${AV_RECORDER_CONTAINER_NAME}-${stream} done"
    done     
    printProgress "Starting container(s) $AV_RECORDER_CONTAINER_NAME done"

    printProgress "Starting container(s) $AV_EDGE_CONTAINER_NAME..."
    for stream in $(echo "${AV_EDGE_STREAM_LIST}" | tr "," "\n")    
    do
        printProgress "Starting container ${AV_EDGE_CONTAINER_NAME}-${stream}..."
        cmd="docker container start ${AV_EDGE_CONTAINER_NAME}-${stream}"
        eval "$cmd"
        checkError
        printProgress "Starting container ${AV_EDGE_CONTAINER_NAME}-${stream} done"
    done     
    printProgress "Starting container(s) $AV_EDGE_CONTAINER_NAME done"

    printProgress "Starting container $AV_WEBAPP_CONTAINER_NAME..."
    cmd="docker container start ${AV_WEBAPP_CONTAINER_NAME}"
    eval "$cmd"
    checkError
    printProgress "Starting container $AV_WEBAPP_CONTAINER_NAME done"



    printMessage "${GREEN}Container started${NC}"
    exit 0
fi

if [ "${action}" = "stop" ]
then
    printMessage "Stopping containers..."
    
    printProgress "Stopping container $AV_RTMP_RTSP_CONTAINER_NAME..."
    cmd="docker container stop ${AV_RTMP_RTSP_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Stopping container $AV_RTMP_RTSP_CONTAINER_NAME done"

    printProgress "Stopping container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME..."
    cmd="docker container stop ${AV_MODEL_YOLO_ONNX_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Stopping container $AV_MODEL_YOLO_ONNX_CONTAINER_NAME done"

    printProgress "Stopping container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME..."
    cmd="docker container stop ${AV_MODEL_COMPUTER_VISION_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Stopping container $AV_MODEL_COMPUTER_VISION_CONTAINER_NAME done"

    # printProgress "Stopping container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME..."
    # cmd="docker container stop ${AV_MODEL_CUSTOM_VISION_CONTAINER_NAME}"
    # eval "$cmd" || true
    # printProgress "Stopping container $AV_MODEL_CUSTOM_VISION_CONTAINER_NAME done"

    printProgress "Stopping container $AV_FFMPEG_CONTAINER_NAME..."
    for stream in $(echo "${AV_FFMPEG_STREAM_LIST}" | tr "," "\n")       
    do
        echo "Stopping container ${AV_FFMPEG_CONTAINER_NAME}-${stream}..."
        cmd="docker container stop \"${AV_FFMPEG_CONTAINER_NAME}-${stream}\""
        eval "$cmd" || true
    done 
    printProgress "Stopping container $AV_FFMPEG_CONTAINER_NAME done"

    printProgress "Stopping container(s) $AV_RECORDER_CONTAINER_NAME..."
    for stream in $(echo "${AV_FFMPEG_STREAM_LIST}" | tr "," "\n")       
    do
        printProgress "Stopping container ${AV_RECORDER_CONTAINER_NAME}-${stream}..."
        cmd="docker container stop ${AV_RECORDER_CONTAINER_NAME}-${stream}"
        eval "$cmd" || true
        printProgress "Stopping container ${AV_RECORDER_CONTAINER_NAME}-${stream} done"
    done         
    printProgress "Stopping container(s) $AV_RECORDER_CONTAINER_NAME done"

    printProgress "Stopping container(s) $AV_EDGE_CONTAINER_NAME..."
    for stream in $(echo "${AV_EDGE_STREAM_LIST}" | tr "," "\n")       
    do
        printProgress "Stopping container ${AV_EDGE_CONTAINER_NAME}-${stream}..."
        cmd="docker container stop ${AV_EDGE_CONTAINER_NAME}-${stream}"
        eval "$cmd" || true
        printProgress "Stopping container ${AV_EDGE_CONTAINER_NAME}-${stream} done"
    done         
    printProgress "Stopping container(s) $AV_EDGE_CONTAINER_NAME done"

    printProgress "Stopping container $AV_WEBAPP_CONTAINER_NAME..."
    cmd="docker container stop ${AV_WEBAPP_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Stopping container $AV_WEBAPP_CONTAINER_NAME done"

    # printProgress "Stopping container $AV_RTSP_SOURCE_CONTAINER_NAME..."
    # cmd="docker container stop ${AV_RTSP_SOURCE_CONTAINER_NAME}"
    # eval "$cmd" || true
    # printProgress "Stopping container $AV_RTSP_SOURCE_CONTAINER_NAME done"

    printProgress "Stopping container $AV_RTSP_SERVER_CONTAINER_NAME..."
    cmd="docker container stop ${AV_RTSP_SERVER_CONTAINER_NAME}"
    eval "$cmd" || true
    printProgress "Stopping container $AV_RTSP_SERVER_CONTAINER_NAME done"

    printMessage "${GREEN}Container stopped${NC}"
    exit 0
fi
