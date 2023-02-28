#!/bin/bash
set -e
BASH_SCRIPT=`readlink -f "$0"`
BASH_DIR=`dirname "$BASH_SCRIPT"`
pushd "$BASH_DIR"  > /dev/null
# colors for formatting the ouput
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
verboseMessage()
{
    printf "${YELLOW}%s${NC}\n" "$*" >&2;
}
errorMessage()
{
    printf "${RED}%s${NC}\n" "$*" >&2;
}
infoMessage()
{
    printf "${BLUE}%s${NC}\n" "$*" >&2;
}
checkError() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}\nAn error occured in createrbacsp.sh bash${NC}"
        exit 1
    fi
}
# Azure input parameters:
# Update AZURE_APP_PREFIX to avoid any possible conflict
export AZURE_APP_PREFIX="rtsp9999"
export ENVIRONMENT="test"
export AZURE_REGION="eastus2"
export RESOURCE_GROUP_NAME="rg${AZURE_APP_PREFIX}${ENVIRONMENT}"
export CONTAINER_REGISTRY_NAME="acr${AZURE_APP_PREFIX}${ENVIRONMENT}"
export CONTAINER_INSTANCE_NAME="aci${AZURE_APP_PREFIX}${ENVIRONMENT}"
export CONTAINER_INSTANCE_IDENTITY_NAME="aciid${AZURE_APP_PREFIX}${ENVIRONMENT}"

infoMessage "Create Resource Group  if not exists"
if [ $(az group exists --name ${RESOURCE_GROUP_NAME}) = false ]; then
    infoMessage "Create resource group  ${RESOURCE_GROUP_NAME}"
    cmd="az group create -l ${AZURE_REGION} -n ${RESOURCE_GROUP_NAME}"
    echo "$cmd"
    eval "$cmd"
    checkError    
fi
infoMessage "Create Azure Container Registry  if not exists"
if [ $(az acr check-name --name ${CONTAINER_REGISTRY_NAME} --query nameAvailable) = true ]; then
    infoMessage "Create Azure Container Registry  ${CONTAINER_REGISTRY_NAME}"
    cmd="az acr create -n ${CONTAINER_REGISTRY_NAME} -g ${RESOURCE_GROUP_NAME} -l ${AZURE_REGION} --sku Basic --admin-enabled false"
    echo "$cmd"
    eval "$cmd"
    checkError
fi
infoMessage "Create User Assigned Identity ${CONTAINER_INSTANCE_IDENTITY_NAME}"
cmd="az identity create --resource-group ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_IDENTITY_NAME}"
echo "$cmd"
eval "$cmd"    
spID=$(az identity show \
--resource-group  ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_IDENTITY_NAME} \
--query principalId --output tsv)

infoMessage "Wait 30 seconds"
sleep 30
infoMessage "Grant Access to the Azure Container Registry ${CONTAINER_REGISTRY_LOGIN_SERVER} from the Azure Container Instance ${CONTAINER_INSTANCE_NAME} role AcrPull"
resourceID=$(az acr show --resource-group  ${RESOURCE_GROUP_NAME} --name ${CONTAINER_REGISTRY_NAME} --query id --output tsv)
cmd="az role assignment create --assignee ${spID} --scope ${resourceID} --role acrpull"
echo "$cmd"
eval "$cmd"
checkError

# Building container input parameters:
export APP_VERSION=$(date +"%y%m%d.%H%M%S")
export RTSPSERVER_NAME="rtspserver"
export IMAGE_FOLDER="analyzer"
export FLAVOR="ubuntu"
export IMAGE_NAME="${RTSPSERVER_NAME}-${FLAVOR}-image"
export IMAGE_TAG=${APP_VERSION}
export CONTAINER_NAME="${RTSPSERVER_NAME}-container"
export ALTERNATIVE_TAG="latest"
export RTSP_SERVER_PORT=554

verboseMessage "APP_VERSION $APP_VERSION"
verboseMessage "IMAGE_NAME $IMAGE_NAME"
verboseMessage "IMAGE_TAG $IMAGE_TAG"
verboseMessage "ALTERNATIVE_TAG $ALTERNATIVE_TAG"
verboseMessage "RTSP_SERVER_PORT $RTSP_SERVER_PORT"
CONTAINER_REGISTRY_LOGIN_SERVER=$(az acr show -n "acr${AZURE_APP_PREFIX}${ENVIRONMENT}" -g "rg${AZURE_APP_PREFIX}${ENVIRONMENT}"  --query loginServer --output tsv)
mkdir -p ./input
cp ./../../../../../content/input/*.mp4 ./input

infoMessage "Build image  ${CONTAINER_REGISTRY_LOGIN_SERVER}/${IMAGE_FOLDER}/${IMAGE_NAME}:${IMAGE_TAG}"
cmd="az acr login  --name ${CONTAINER_REGISTRY_NAME}"
echo "$cmd"
eval "$cmd"  
checkError

cmd="az acr build -t ${IMAGE_FOLDER}/${IMAGE_NAME}:${IMAGE_TAG} -r  ${CONTAINER_REGISTRY_NAME} -g  ${RESOURCE_GROUP_NAME} ."
echo "$cmd"
eval "$cmd"  
checkError

cmd="az acr import --name  ${CONTAINER_REGISTRY_NAME} -g  ${RESOURCE_GROUP_NAME} --source ${CONTAINER_REGISTRY_LOGIN_SERVER}/${IMAGE_FOLDER}/${IMAGE_NAME}:${IMAGE_TAG} --image ${IMAGE_FOLDER}/${IMAGE_NAME}:${ALTERNATIVE_TAG} --force"
echo "$cmd"
eval "$cmd"  
checkError

identityResourceID=$(az identity show \
--resource-group  ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_IDENTITY_NAME} \
--query id --output tsv)

cmd="az container create --resource-group ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_NAME} --image ${CONTAINER_REGISTRY_LOGIN_SERVER}/${IMAGE_FOLDER}/${IMAGE_NAME}:${ALTERNATIVE_TAG} --dns-name-label ${CONTAINER_INSTANCE_NAME} --ports ${RTSP_SERVER_PORT} -e PORT_RTSP=${RTSP_SERVER_PORT} --acr-identity ${identityResourceID}  --assign-identity ${identityResourceID}"
echo "$cmd"
eval "$cmd" 
checkError
  
DNS_NAME=$(az container show --resource-group ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_NAME} | jq -r '.ipAddress.fqdn')
for i in ./input/*.mp4 
do 
infoMessage "Run the following command:"
infoMessage "  ffprobe -i rtsp://${DNS_NAME}:${RTSP_SERVER_PORT}/media/$(basename $i)"
done
infoMessage "Deploying the RTSP server to emulate Live RTSP streams done..."


# Remove temporary folder with mp4 files
rm ./input/*.mp4 > /dev/null
rmdir ./input > /dev/null
popd  > /dev/null
