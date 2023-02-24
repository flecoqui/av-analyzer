import { default as config } from "./config.json";

type AppGlobalConfig = {
    version: string;
    storageAccountResultUrl: string;
    storageAccountResultSASToken: string;
    storageAccountRecordUrl: string;
    storageAccountRecordSASToken: string;
    storageFolder: string;
    cameraList: string;
    cameraUrlPrefix: string;
    logLevel: string;
    frameExtensions: Array<string>;
    videoExtensions: Array<string>;
    resultExtensions: Array<string>;
};

declare global {
    var globalConfiguration: AppGlobalConfig;
}
globalThis.globalConfiguration = {
    version: config.version,
    storageAccountResultUrl: config.storageAccountResultUrl,
    storageAccountResultSASToken: config.storageAccountResultSASToken,
    storageAccountRecordUrl: config.storageAccountRecordUrl,
    storageAccountRecordSASToken: config.storageAccountRecordSASToken,
    storageFolder: config.storageFolder,
    cameraList: config.cameraList,
    cameraUrlPrefix: config.cameraUrlPrefix,
    logLevel: config.logLevel,
    frameExtensions: config.frameExtensions,
    videoExtensions: config.videoExtensions,
    resultExtensions: config.resultExtensions,
}; 


export { };