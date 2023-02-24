import './globalconfig';
import { Page } from "./page";
import { LogClient } from './logclient';
import { PageWaiting, ButtonWaiting, WaitCursorForm } from './notificationclient';
import { isNullOrUndefinedOrEmpty } from "./common";
import videojs, { VideoJsPlayer } from 'video.js';

class LivePage extends Page {
  version: string;
  logClient: LogClient;
  static current?: LivePage;
  cameraList: string[];
  cameraIndex: number;
  constructor(id: string,
    name: string,
    uri: string | null,
    content: string | null,
    version: string,
    logClient: LogClient,
    sourceList: string[]
  ) {
    super(id, name, uri, content);
    this.version = version;
    this.logClient = logClient;
    this.cameraList = sourceList;
    this.cameraIndex = 0;
    LivePage.current = this;
  }
  logMessage(message: string) {
    this.logClient.log(message);
    this.setHTMLValueText("liveMessage", message);
  }
  logError(message: string) {
    this.logClient.error(message);
    this.setHTMLValueText("liveError", message);
  }
  // Read config file at runtime 
  // as it has been updated when the container started up 
  getCameraPrefixUrl():Promise<string>{
    return new Promise<string>((resolve, reject) => {
      (async () => {
        try {
          const response  = await fetch('./config.json');
          const body = await response.json();
          resolve (body.cameraUrlPrefix)
        }
        catch (reason) {
          const message = "Exception while reading config.json"
          this.logError(message);
          reject(message);
          return;
        }
      })();
    });
  }
  async fillCameraCombo(comboId: string, list: string[]|null) {
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
          const urlPrefix:string = await this.getCameraPrefixUrl();
          for (let i = 0; i < list.length; i++) {
            const opt = document.createElement("option"); // Create the new element
            opt.text = list[i];
            opt.value = `${urlPrefix}/${list[i]}.m3u8`;
            comboList.options.add(opt);
          }
          comboList.selectedIndex = 0;
          comboList.dispatchEvent(new Event('change', { bubbles: true }));
        }
    }
  }    
  playPrev(){
    this.cameraIndex = this.cameraIndex - 1;
    if(this.cameraIndex < 0)
      this.cameraIndex = 0;
    this.updatePlayControls();  
  }
  playNext(){
    this.cameraIndex = this.cameraIndex + 1;
    if(this.cameraIndex > (this.cameraList.length-1))
      this.cameraIndex = this.cameraList.length-1;
      this.updatePlayControls();  
  }
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
  async currentCameraChange(){
    var waiting = new PageWaiting("liveWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading Slots"));
    try
    {
      const uriCombo = (<HTMLSelectElement>document.getElementById("liveListCamera"));
      if (uriCombo) {
        if((uriCombo.options.selectedIndex >= 0)&&
        (uriCombo.options.selectedIndex <= (this.cameraList.length-1)))
        {
          this.cameraIndex = uriCombo.options.selectedIndex;
          var player = <HTMLVideoElement>document.getElementById("livePlayer");
          if(player){
           // player.src({ type: "application/x-mpegURL", src: `${uriCombo.options[uriCombo.options.selectedIndex].value}` });
           // player.load();
           // player.play();
             var p = videojs("#livePlayer");
             if(p){ 
                p.src({ type: "application/x-mpegURL", src: `${uriCombo.options[uriCombo.options.selectedIndex].value}` });
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
           }     
       
          }          
        }
        this.updatePlayControls();  
    }
    catch(e){
    }
    finally{
      waiting.hide();  
    }
  }
  static StaticPrev() {
    if (LivePage.current)
    LivePage.current.playPrev();
  }   
  static StaticNext() {
    if (LivePage.current)
    LivePage.current.playNext();
  }   
  static StaticCurrentCameraChange() {
    if (LivePage.current)
    LivePage.current.currentCameraChange();
  }   
  updatePlayControls() {
    const prevButton = (<HTMLButtonElement>document.getElementById("livePrev"));
    if (prevButton) {
      if(this.cameraIndex == 0)
        prevButton.disabled = true;
      else
        prevButton.disabled = false;
    }
    const nextButton = (<HTMLButtonElement>document.getElementById("liveNext"));
    if (nextButton) {
      if(this.cameraIndex == (this.cameraList.length-1))
        nextButton.disabled = true;
      else
        nextButton.disabled = false;
    }
    const uriCombo = (<HTMLSelectElement>document.getElementById("liveListCamera"));
    if (uriCombo) {
      uriCombo.options.selectedIndex = this.cameraIndex;
      uriCombo.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }

  registerEvents(): boolean {
    this.logClient.log("LivePage registerEvents");

    super.addEvent("livePrev", "click", LivePage.StaticPrev);
    super.addEvent("liveNext", "click", LivePage.StaticNext);
    super.addEvent("liveListCamera", "change", LivePage.StaticCurrentCameraChange); 
    return true;
  }

  unregisterEvents(): boolean {
    this.logClient.log("LivePage unregisterEvents");

    super.removeEvent("livePrev", "click", LivePage.StaticPrev);
    super.removeEvent("liveNext", "click", LivePage.StaticNext);   
    super.removeEvent("liveListCamera", "change", LivePage.StaticCurrentCameraChange); 
    return true;
  }


  onInitializePage(): boolean {
    var waiting = new PageWaiting("liveWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading cameras"));
    this.addHTMLValueMap([
      { id: "livePageTitle",  value: globalThis.globalVars.getCurrentString("Live Page"), readonly: true },
    ]);
    this.updateData(false);
    // Initialize Page  
    this.fillCameraCombo("liveListCamera",this.cameraList);
    this.updatePlayControls();

    waiting.hide();
    return true;
  }
}
let localPage = new LivePage("content", "Live", "live.html", null,
  globalThis.globalConfiguration.version,
  globalThis.globalClient.getLogClient(),
  globalThis.globalClient.getCameraList());
  
if (localPage) {
  
  localPage.initializePage();
}

