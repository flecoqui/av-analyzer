import './globalconfig';
import { Page } from "./page";
import { LogClient } from './logclient';
import { StorageClient } from './storage';
import { PageWaiting, ButtonWaiting, WaitCursorForm } from './notificationclient';
import { isNullOrUndefinedOrEmpty } from "./common";
import videojs, { VideoJsPlayer } from 'video.js';


class RecordPage extends Page {
  version: string;
  logClient: LogClient;
  storageClient: StorageClient;
  static current?: RecordPage;
  returnedBlobUrls: string[];
  returnedBlobUrlIndex: number;
  storageFolder: string;
  cameraList: string[];
  cameraIndex: number;
  slotList: string[];
  slotIndex: number;
  constructor(id: string,
    name: string,
    uri: string | null,
    content: string | null,
    version: string,
    logClient: LogClient,
    storageClient: StorageClient,
    folder: string,
    sourceList: string[]
  ) {
    super(id, name, uri, content);
    this.version = version;
    this.logClient = logClient;
    this.storageClient = storageClient;
    this.cameraList = sourceList;
    this.cameraIndex = 0;
    this.slotList = [];
    this.slotIndex = 0;
    this.storageFolder = folder;
    this.returnedBlobUrls = [];
    this.returnedBlobUrlIndex = 0;
    RecordPage.current = this;
  }
  logMessage(message: string) {
    this.logClient.log(message);
    this.setHTMLValueText("recordMessage", message);
  }
  logError(message: string) {
    this.logClient.error(message);
    this.setHTMLValueText("recordError", message);
  }
  getListBlobs(folder: string, subfolder: string[]|null = null) {
    return new Promise<number>(async (resolve: (value: number | PromiseLike<number>) => void, reject: (reason?: any) => void) => {
      try {
          if (this.storageClient) {
            this.returnedBlobUrls = [];
            let localList:string[] = await this.storageClient.getBlobsInFolder(folder, subfolder);
            if (localList) {
              for(let i = 0; i < localList.length; i++){
                if((localList[i].endsWith(".mp4")) && (localList[i].indexOf(folder)>0))
                this.returnedBlobUrls.push(localList[i])
              }
              this.returnedBlobUrlIndex = 0;
              resolve(this.returnedBlobUrls.length);
            }
            else {
              var error = "Error while getting blobs : response null";
              this.logError(error);
              reject(error);
            }
          }
          else {
            var error = "Internal Error apiclient null";
            this.logError(error);
            reject(error);
          }
        }
        catch (e) {
          var error = `Exception while getting Blobs: ${e}`;
          this.logError(error);
          reject(error);
        }
        return true;
    });
  } 

  fillCameraCombo(comboId: string, list: string[]|null): void {
    const comboList = (<HTMLSelectElement>document.getElementById(comboId));
    if ((comboList)&&(!isNullOrUndefinedOrEmpty(comboList.options))) {
      let len = comboList.options.length - 1;
      while (len >= 0)
        comboList.options.remove(len--);
      if(list!=null)
        if(list.length == 0){
          const opt = document.createElement("option"); // Create the new element
          opt.text = globalThis.globalVars.getCurrentString('Empty list');
          opt.value = "";
          comboList.options.add(opt);
          comboList.selectedIndex = 0;
          comboList.dispatchEvent(new Event('change', { bubbles: true }));
        } 
        else
        {     
          for (let i = 0; i < list.length; i++) {
            const opt = document.createElement("option"); // Create the new element
            opt.text = list[i];
            opt.value = list[i];
            comboList.options.add(opt);
          }
          comboList.selectedIndex = 0;
          comboList.dispatchEvent(new Event('change', { bubbles: true }));
        }
    }
  }    
  fillSlotCombo(comboId: string, list: string[]|null): void {
    const comboList = (<HTMLSelectElement>document.getElementById(comboId));
    if ((comboList)&&(!isNullOrUndefinedOrEmpty(comboList.options))) {
      let len = comboList.options.length - 1;
      while (len >= 0)
        comboList.options.remove(len--);
      if(list!=null)
        if(list.length == 0){
          const opt = document.createElement("option"); // Create the new element
          opt.text = globalThis.globalVars.getCurrentString('Empty list');
          opt.value = "";
          comboList.options.add(opt);
          comboList.selectedIndex = 0;
          comboList.dispatchEvent(new Event('change', { bubbles: true }));
        } 
        else
        {     
          for (let i = 0; i < list.length; i++) {
            const opt = document.createElement("option"); // Create the new element
            opt.text = list[i];
            opt.value = list[i];
            comboList.options.add(opt);
          }
          comboList.selectedIndex = 0;
          comboList.dispatchEvent(new Event('change', { bubbles: true }));
        }
    }
  }    

  fillFrameCombo(comboId: string, list: string[]|null): void {
    const comboListUri = (<HTMLSelectElement>document.getElementById(comboId));
    if ((comboListUri)&&(!isNullOrUndefinedOrEmpty(comboListUri.options))) {
      let len = comboListUri.options.length - 1;
      while (len >= 0)
        comboListUri.options.remove(len--);
      if(list!=null)
        if(list.length == 0){
          const opt = document.createElement("option"); // Create the new element
          opt.text = globalThis.globalVars.getCurrentString('Empty list');
          opt.value = "";
          comboListUri.options.add(opt);
          comboListUri.selectedIndex = 0;
          comboListUri.dispatchEvent(new Event('change', { bubbles: true }));
        } 
        else
        {     
          for (let i = 0; i < list.length; i++) {
            const opt = document.createElement("option"); // Create the new element
            opt.text = list[i];
            opt.value = list[i];
            comboListUri.options.add(opt);
          }
          comboListUri.selectedIndex = 0;
          comboListUri.dispatchEvent(new Event('change', { bubbles: true }));
        }
    }
  }    
  playCarousel(): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        const waiting = new ButtonWaiting("recordPlay");
        waiting.show(WaitCursorForm.grow);        
        try {
          this.returnedBlobUrlIndex = 0;
          this.displayVideo();
          this.updatePlayControls();           
        }
        catch (reason) {
          const message = `Exception while displaying frames from account ${this.storageClient.getStorageAccount()} and container ${this.storageClient.getStorageContainer()} reason: ${reason}`;
          this.logError(message);
          reject(message);
          return;
        }
        finally {
          waiting.hide();
        }        
      })();
    });
  }  
  protected callAPIAsync(method: string, endpoint: string, token: string, payload: string | null): Promise<Response> {
    return new Promise<Response>(async (resolve, reject) => {

      try {
        const url = `${endpoint}?${token}`
        const headers = new Headers();
        headers.append("Content-Type", "application/json");

        var options;
        if (method == "GET") {
          options = {
            method: method,
            headers: headers,
          };
        }
        else if (method == "POST") {
          options = {
            method: method,
            headers: headers,
            body: JSON.stringify(payload)
          };
        }
        else if (method == "PUT") {
          options = {
            method: method,
            headers: headers,
            body: JSON.stringify(payload)
          };
        }
        else if (method == "DELETE") {
          options = {
            method: method,
            headers: headers,
          };
        }
        var response = await fetch(url, options);
        if (response)
          resolve(response)
      }
      catch (error) {
        this.logClient.error(error);
        reject(error);
      }
    });
  };  
  getCurrentTime (player: VideoJsPlayer) {
    if(player){
      if(player.liveTracker){
        let currentTime = (<HTMLSpanElement>document.getElementById("timer"));
        currentTime.innerHTML = this.formatTime(player.liveTracker.liveCurrentTime());
      }
    }
  }
  formatTime (time:number) {
    return (Math.round(time * 1000000) / 1000000).toFixed(6);
  }  
  displayVideo(){

      let playDiv = (<HTMLDivElement>document.getElementById("playImageDiv"));
      let recordPlayer = (<HTMLVideoElement>document.getElementById("recordPlayer"));
            
      if((recordPlayer)&&(playDiv)){      
        var p = videojs("#recordPlayer");
        if(p){
          p.on('timeupdate', () => {
            (<HTMLDivElement>document.getElementById("timer")).innerHTML = p.currentTime.toString();
            console.log(p.currentTime.toString());
          });
          p.src({ src: `${this.returnedBlobUrls[this.returnedBlobUrlIndex]}?${globalConfiguration.storageAccountRecordSASToken}` });
          p.load();
          p.play();
          var tracker = p.liveTracker;
          if(tracker)
          {
              p.on(tracker, "liveedgechange", () => {this.getCurrentTime(p)});
              p.on(tracker, "seekableendchange", () => {this.getCurrentTime(p)}); 
              p.on("timeupdate", () => {this.getCurrentTime(p)}); 
          }
        }
      };    
  }
  playPrev(){
    this.returnedBlobUrlIndex = this.returnedBlobUrlIndex - 1;
    if(this.returnedBlobUrlIndex < 0)
      this.returnedBlobUrlIndex = 0;
    this.displayVideo();
    this.updatePlayControls();  
  }
  playNext(){
    this.returnedBlobUrlIndex = this.returnedBlobUrlIndex + 1;
    if(this.returnedBlobUrlIndex > (this.returnedBlobUrls.length-1))
      this.returnedBlobUrlIndex = this.returnedBlobUrls.length-1;
      this.displayVideo();
      this.updatePlayControls();  
  }
  getSlot(camera: string, uri: string):string {
    let index = uri.indexOf(camera);
    if(index>0){
      let lastIndex = uri.indexOf("/",index+camera.length+1);
      if(lastIndex>0)
        return uri.substring(index+camera.length+1,lastIndex);
    }
    return "";
  }
  addSlot(slot: string){
    for( let i = 0; i < this.slotList.length; i++)
    {
      if(this.slotList[i] == slot)
        return;
    }
    this.slotList.push(slot);
  }
  getSlotList(camera: string): string[]{
    this.slotList = [];
    for(let i=0; i<this.returnedBlobUrls.length;i++){
      let slot:string = this.getSlot(camera,this.returnedBlobUrls[i]);
      if(slot)
        this.addSlot(slot);
    }
    return this.slotList;
  }
  async currentCameraChange(){
    var waiting = new PageWaiting("recordWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading Slots"));
    try
    {
      const uriCombo = (<HTMLSelectElement>document.getElementById("recordListCamera"));
      if (uriCombo) {
        if((uriCombo.options.selectedIndex >= 0)&&
        (uriCombo.options.selectedIndex <= (this.cameraList.length-1)))
        {
          this.cameraIndex = uriCombo.options.selectedIndex;
          await this.getListBlobs(`${this.storageFolder}/${this.cameraList[this.cameraIndex]}`);
          this.fillSlotCombo("recordListSlot",this.getSlotList(this.cameraList[this.cameraIndex]));
        }
      }
    }    
    catch(e){
    }
    finally{
      waiting.hide();  
    }
  }
  async currentSlotChange(){
    var waiting = new PageWaiting("recordWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading blobs"));
    try
    {
      const uriCombo = (<HTMLSelectElement>document.getElementById("recordListSlot"));
      if (uriCombo) {
        if((uriCombo.options.selectedIndex >= 0)&&
        (uriCombo.options.selectedIndex <= (this.slotList.length-1)))
        {
          this.slotIndex = uriCombo.options.selectedIndex;
          await this.getListBlobs(`${this.storageFolder}/${this.cameraList[this.cameraIndex]}/${this.slotList[this.slotIndex]}`);
          this.fillFrameCombo("recordListUri",this.returnedBlobUrls);
        }
      }    
      this.displayVideo();
      this.updatePlayControls();
    }
    catch(e){
    }
    finally{
      waiting.hide();  
    }
  }

  currentFrameChange(){
    var waiting = new PageWaiting("recordWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Playing blobs"));
    try
    {
      const uriCombo = (<HTMLSelectElement>document.getElementById("recordListUri"));
      if (uriCombo) {
        if((uriCombo.options.selectedIndex >= 0)&&
        (uriCombo.options.selectedIndex <= (this.returnedBlobUrls.length-1)))
        {
          this.returnedBlobUrlIndex = uriCombo.options.selectedIndex;
        }
      }    
      this.displayVideo();
      this.updatePlayControls();
    }
    catch(e){
    } 
    finally{
      waiting.hide();  
    } 
  }

 
  static StaticPrev() {
    if (RecordPage.current)
    RecordPage.current.playPrev();
  }   
  static StaticNext() {
    if (RecordPage.current)
    RecordPage.current.playNext();
  }   
  static StaticCurrentCameraChange() {
    if (RecordPage.current)
    RecordPage.current.currentCameraChange();
  }   
  static StaticCurrentSlotChange() {
    if (RecordPage.current)
    RecordPage.current.currentSlotChange();
  }   
  static StaticCurrentFrameChange() {
    if (RecordPage.current)
    RecordPage.current.currentFrameChange();
  }   
  updatePlayControls() {
    const prevButton = (<HTMLButtonElement>document.getElementById("recordPrev"));
    if (prevButton) {
      if(this.returnedBlobUrlIndex == 0)
        prevButton.disabled = true;
      else
        prevButton.disabled = false;
    }
    const nextButton = (<HTMLButtonElement>document.getElementById("recordNext"));
    if (nextButton) {
      if(this.returnedBlobUrlIndex == (this.returnedBlobUrls.length-1))
        nextButton.disabled = true;
      else
        nextButton.disabled = false;
    }
    const uriCombo = (<HTMLSelectElement>document.getElementById("recordListUri"));
    if (uriCombo) {
      uriCombo.options.selectedIndex = this.returnedBlobUrlIndex;
    }
  }

  registerEvents(): boolean {
    this.logClient.log("RecordPage registerEvents");


    super.addEvent("recordPrev", "click", RecordPage.StaticPrev);
    super.addEvent("recordNext", "click", RecordPage.StaticNext);
    super.addEvent("recordListCamera", "change", RecordPage.StaticCurrentCameraChange); 
    super.addEvent("recordListSlot", "change", RecordPage.StaticCurrentSlotChange); 
    super.addEvent("recordListUri", "change", RecordPage.StaticCurrentFrameChange); 
    return true;
  }

  unregisterEvents(): boolean {
    this.logClient.log("RecordPage unregisterEvents");


    super.removeEvent("recordPrev", "click", RecordPage.StaticPrev);
    super.removeEvent("recordNext", "click", RecordPage.StaticNext);   
    super.removeEvent("recordListCamera", "change", RecordPage.StaticCurrentCameraChange); 
    super.removeEvent("recordListSlot", "change", RecordPage.StaticCurrentSlotChange); 
    super.removeEvent("recordListUri", "change", RecordPage.StaticCurrentFrameChange); 
    return true;
  }


  onInitializePage(): boolean {
    var waiting = new PageWaiting("recordWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading blob records"));
    this.addHTMLValueMap([
      { id: "recordPageTitle",  value: globalThis.globalVars.getCurrentString("Results Page"), readonly: true },
    ]);
    this.updateData(false);
    // Initialize Page  
    this.fillCameraCombo("recordListCamera",this.cameraList);

    /*
    this.getListBlobs(this.storageFolder,this.cameraList)
      .then((count) => {
        this.logMessage(`${count} frame record(s) in results table`);
        this.fillFrameCombo("recordListUri",this.returnedBlobUrls);
        this.playCarousel();
        this.updatePlayControls();

      })
      .catch((e) => {
        this.logError(`Error while loading page: ${e}`);
      })
      .finally(() => {
        waiting.hide();
      });
    */

    waiting.hide();
    return true;
  }
}
let localPage = new RecordPage("content", "Home", "record.html", null,
  globalThis.globalConfiguration.version,
  globalThis.globalClient.getLogClient(),
  globalThis.globalClient.getStorageRecordClient(),
  globalThis.globalClient.getStorageFolder(),
  globalThis.globalClient.getCameraList());
  
if (localPage) {
  
  localPage.initializePage();
}

