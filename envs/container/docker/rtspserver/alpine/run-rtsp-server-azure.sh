#!/bin/bash
set -e
BASH_SCRIPT=`readlink -f "$0"`
BASH_DIR=`dirname "$BASH_SCRIPT"`
pushd "$BASH_DIR"  > /dev/null

# Azure input parameters:
# Update AZURE_APP_PREFIX to avoid any possible conflict
export AZURE_APP_PREFIX="rtsp9999"
export ENVIRONMENT="test"
export AZURE_REGION="eastus2"
export RESOURCE_GROUP_NAME: "rg${AZURE_APP_PREFIX}${ENVIRONMENT}"
export CONTAINER_REGISTRY_NAME: "acr${AZURE_APP_PREFIX}${ENVIRONMENT}"
export CONTAINER_INSTANCE_NAME: "aci${AZURE_APP_PREFIX}${ENVIRONMENT}"

echo "Create Resource Group  if not exists"
if [ $(az group exists --name ${RESOURCE_GROUP_NAME}) = false ]; then
    echo "Create resource group  ${RESOURCE_GROUP_NAME}"
    cmd="az group create -l ${AZURE_REGION} -n ${RESOURCE_GROUP_NAME}"
    echo "$cmd"
    eval "$cmd"    
fi
echo "Create Azure Container Registry  if not exists"
if [ $(az acr check-name --name ${CONTAINER_REGISTRY_NAME} --query nameAvailable) = true ]; then
    echo "Create Azure Container Registry  ${CONTAINER_REGISTRY_NAME}"
    cmd="az acr create -n ${CONTAINER_REGISTRY_NAME} -g ${RESOURCE_GROUP_NAME} -l ${AZURE_REGION} --sku Basic --admin-enabled false"
    echo "$cmd"
    eval "$cmd"
fi
echo "Create User Assigned Identity ${CONTAINER_INSTANCE_IDENTITY_NAME}"
cmd="az identity create --resource-group ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_IDENTITY_NAME}"
echo "$cmd"
eval "$cmd"    
spID=$(az identity show \
--resource-group  ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_IDENTITY_NAME} \
--query principalId --output tsv)

echo "Wait 30 seconds"
sleep 30
echo "Grant Access to the Azure Container Registry ${CONTAINER_REGISTRY_LOGIN_SERVER} from the Azure Container Instance ${CONTAINER_INSTANCE_NAME} role AcrPull"
resourceID=$(az acr show --resource-group  ${RESOURCE_GROUP_NAME} --name ${CONTAINER_REGISTRY_NAME} --query id --output tsv)
cmd="az role assignment create --assignee ${spID} --scope ${resourceID} --role acrpull"
echo "$cmd"
eval "$cmd"

# Building container input parameters:
export APP_VERSION=$(date +"%y%m%d.%H%M%S")
export RTSPSERVER_NAME="rtspserver"
export IMAGE_FOLDER="analyzer"
export FLAVOR="alpine"
export IMAGE_NAME="${RTSPSERVER_NAME}-${FLAVOR}-image"
export IMAGE_TAG=${APP_VERSION}
export CONTAINER_NAME="${RTSPSERVER_NAME}-container"
export ALTERNATIVE_TAG="latest"
export RTSP_SERVER_PORT_RTSP=554

echo "APP_VERSION $APP_VERSION"
echo "IMAGE_NAME $IMAGE_NAME"
echo "IMAGE_TAG $IMAGE_TAG"
echo "ALTERNATIVE_TAG $ALTERNATIVE_TAG"
echo "RTSP_SERVER_PORT_RTSP $RTSP_SERVER_PORT_RTSP"
CONTAINER_REGISTRY_LOGIN_SERVER=$(az acr show -n "acr${AZURE_APP_PREFIX}${ENVIRONMENT}" -g "rg${AZURE_APP_PREFIX}${ENVIRONMENT}"  --query loginServer --output tsv)
mkdir -p ./input
cp ./../../../../../content/input/*.mp4 ./input
echo "Build image  ${CONTAINER_REGISTRY_LOGIN_SERVER}/${IMAGE_FOLDER}/${IMAGE_NAME}:${IMAGE_TAG}"
cmd="az acr login  --name ${CONTAINER_REGISTRY_NAME}"
echo "$cmd"
eval "$cmd"  

cmd="az acr build -t ${IMAGE_FOLDER}/${IMAGE_NAME}:${IMAGE_TAG} -r  ${CONTAINER_REGISTRY_NAME} -g  ${RESOURCE_GROUP_NAME} ."
echo "$cmd"
eval "$cmd"  
cmd="az acr import --name  ${CONTAINER_REGISTRY_NAME} -g  ${RESOURCE_GROUP_NAME} --source ${CONTAINER_REGISTRY_LOGIN_SERVER}/${IMAGE_FOLDER}/${IMAGE_NAME}:${IMAGE_TAG} --image ${IMAGE_FOLDER}/${IMAGE_NAME}:${ALTERNATIVE_TAG} --force"
echo "$cmd"
eval "$cmd"  

identityResourceID=$(az identity show \
--resource-group  ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_IDENTITY_NAME} \
--query id --output tsv)

cmd="az container create --resource-group ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_NAME} --image ${CONTAINER_REGISTRY_LOGIN_SERVER}/${IMAGE_FOLDER}/${IMAGE_NAME}:${ALTERNATIVE_TAG} --dns-name-label ${CONTAINER_INSTANCE_NAME} --ports ${RTSP_SERVER_PORT} -e PORT_RTSP=${RTSP_SERVER_PORT} --acr-identity ${identityResourceID}  --assign-identity ${identityResourceID}"
echo "$cmd"
eval "$cmd"    
DNS_NAME=$(az container show --resource-group ${RESOURCE_GROUP_NAME} --name ${CONTAINER_INSTANCE_NAME} | jq -r '.ipAddress.fqdn')
for i in ./input/*.mp4 
do 
echo "Run the following command:"
echo "  ffprobe -i rtsp://${DNS_NAME}:${RTSP_SERVER_PORT}/media/$(basename $i)"
done
echo "Deploying the RTSP server to emulate the cameras done"


# Remove temporary folder with mp4 files
rm ./input/*.mp4 > /dev/null
rmdir ./input > /dev/null
popd  > /dev/null