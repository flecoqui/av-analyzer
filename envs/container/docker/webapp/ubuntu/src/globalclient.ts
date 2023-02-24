import { StorageClient } from "./storage";
import { LogClient } from "./logclient";
import "./globalconfig";


const globalConfig = globalThis.globalConfiguration;

export class GlobalClient {

    // Initialize logClient
    private logClient: LogClient = new LogClient(LogClient.getLogLevelFromString(globalConfig.logLevel));

    // Initialize the StorageClient used for the access to Azure Storage
    private storageResultClient: StorageClient = new StorageClient(
        this.logClient, 
        this.getStorageAccount(globalConfig.storageAccountResultUrl),
        this.getContainer(globalConfig.storageAccountResultUrl),
        globalConfig.storageAccountResultSASToken
    )
    private storageRecordClient: StorageClient = new StorageClient(
        this.logClient, 
        this.getStorageAccount(globalConfig.storageAccountRecordUrl),
        this.getContainer(globalConfig.storageAccountRecordUrl),
        globalConfig.storageAccountRecordSASToken
    )

    public getStorageResultClient(): StorageClient {
        return this.storageResultClient;
    }        
    public getStorageRecordClient(): StorageClient {
        return this.storageRecordClient;
    }

    private cameraList:string = globalConfig.cameraList;        
    public getCameraList(): string[] {
        return this.cameraList.split(",");
    }
    private cameraUrlPrefix:string = globalConfig.cameraUrlPrefix;        
    public getCameraUrlPrefix(): string {
        return this.cameraUrlPrefix;
    }
    private storageFolder:string = globalConfig.storageFolder;
    public getStorageFolder(): string {
        return this.storageFolder;
    }

    public getLogClient(): LogClient {
        return this.logClient;
    }
    public  getStorageAccount(url: string):string{
        url=url.replace("https://","");
        var splitted = url.split(".",1);
        return splitted[0];
    }
    public  getContainer(url: string):string{
        var splitted = url.split("/");
        return splitted[3];
    }
}
declare global {
    var globalClient: GlobalClient;
}
declare var globalClient: GlobalClient;
globalThis.globalClient = new GlobalClient();
