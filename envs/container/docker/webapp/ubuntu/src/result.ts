import './globalconfig';
import { Page } from "./page";
import { LogClient } from './logclient';
import { StorageClient } from './storage';
import { PageWaiting, ButtonWaiting, WaitCursorForm } from './notificationclient';
import { isNullOrUndefinedOrEmpty } from "./common";
import { YoloInferences } from "./yolomodel";
import { ComputerVisionInferences } from "./computervisionmodel";
import { CustomVisionInferences } from "./customvisionmodel";
import { addSyntheticLeadingComment } from 'typescript';

/*
const globalConfig = globalThis.globalConfiguration;
if (globalConfig) {
  //console.log("Reading globalConfig")

  var s = document.getElementById('versionButton');
  if (s) {
    //console.log(`versionButton set to ${globalConfig.version}`);
    s.innerHTML = globalConfig.version;
  }
  else
    console.log("Error: versionButton not defined");
}
else
  console.log("Error: getGlobalConfiguration not defined");
*/
class ResultPage extends Page {
  version: string;
  logClient: LogClient;
  storageClient: StorageClient;
  static current?: ResultPage;
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
    ResultPage.current = this;
  }
  logMessage(message: string) {
    this.logClient.log(message);
    this.setHTMLValueText("resultMessage", message);
  }
  logError(message: string) {
    this.logClient.error(message);
    this.setHTMLValueText("resultError", message);
  }
  getListBlobs(folder: string, subfolder: string[]|null = null) {
    return new Promise<number>(async (resolve: (value: number | PromiseLike<number>) => void, reject: (reason?: any) => void) => {
      try {
          if (this.storageClient) {
            this.returnedBlobUrls = [];
            let localList:string[] = await this.storageClient.getBlobsInFolder(folder, subfolder);
            if (localList) {
              for(let i = 0; i < localList.length; i++){
                if((localList[i].endsWith(".jpg")) && (localList[i].indexOf(folder)>0))
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
        const waiting = new ButtonWaiting("resultPlay");
        waiting.show(WaitCursorForm.grow);        
        try {
          this.returnedBlobUrlIndex = 0;
          this.displayFrame();
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
  drawMessage(context:CanvasRenderingContext2D,message:string, top: number = 1, left: number = 1, color: string = "red", fSize: number = 40){
    context.beginPath();    
    const fontSize = fSize;
    context.font = `${fontSize}px Verdana`;
    context.fillStyle = color;

    let t=(1+top)*fontSize;
    let l=(1+left)*fontSize;            
    context.fillText(message,
      l,t);
    context.stroke();
    context.closePath();
  }
  drawRects(context:CanvasRenderingContext2D,jsonString:string|null, canvasWidth:number, canvasHeight:number, imageWidth:number, imageHeight:number){    
    
    if((jsonString)&&(jsonString.length>0)){
      if(jsonString.startsWith("{\"inferences\"")){
          const yoloInferences:YoloInferences = JSON.parse(jsonString) as YoloInferences;
          if((yoloInferences)&&(yoloInferences.inferences))
            this.drawYoloRects(context,yoloInferences,canvasWidth,canvasHeight, imageWidth, imageHeight );
          else
            this.drawMessage(context, `Json string not parsed correctly as Yolo model result: ${jsonString}`);
      }
      else if(jsonString.startsWith("{\"categories\"")){
        const computerVisionInferences:ComputerVisionInferences = JSON.parse(jsonString) as ComputerVisionInferences;
        if(computerVisionInferences)
          this.drawComputerVisionRects(context,computerVisionInferences,canvasWidth,canvasHeight, imageWidth, imageHeight );
        else
          this.drawMessage(context, `Json string not parsed correctly as Computer Vision model result: ${jsonString}`);
      }
      else if(jsonString.startsWith("{\"id\"")){
        const customVisionInferences:CustomVisionInferences = JSON.parse(jsonString) as CustomVisionInferences;
        if(customVisionInferences)
          this.drawCustomVisionRects(context,customVisionInferences,canvasWidth,canvasHeight, imageWidth, imageHeight );
        else
          this.drawMessage(context, `Json string not parsed correctly as Custom Vision model result: ${jsonString}`);
      }
      else if(jsonString.startsWith("{}")){
        this.drawMessage(context, "No object detected",1,1,"yellow",20);
      }
      else
      {
        this.drawMessage(context, `No model available for the json: ${jsonString}`);
      }
    }
    else
    {
      this.drawMessage(context, "Inference Json string empty");
    }
  }
  drawComputerVisionRects(context:CanvasRenderingContext2D,inferences:ComputerVisionInferences, canvasWidth:number, canvasHeight:number, imageWidth:number, imageHeight:number){
    if(inferences)
    {
      for(let i = 0; i < inferences.categories.length; i++){
        if((inferences.categories[i].name)&&
          (inferences.categories[i].score>0)){
            this.drawMessage(context,`category: ${inferences.categories[i].name} score: ${inferences.categories[i].score}`, i,1, "green",20);
          }
        }
      for(let i = 0; i < inferences.tags.length; i++){
        if((inferences.tags[i].name)&&
          (inferences.tags[i].confidence>0)){
            this.drawMessage(context,`tag: ${inferences.tags[i].name} confidence: ${inferences.tags[i].confidence}`, inferences.categories.length+i,1, "blue",20);
          }
        }        
      for(let i = 0; i < inferences.objects.length; i++){
        if((inferences.objects[i].object)&&
          (inferences.objects[i].confidence>0)){
              
            context.beginPath();
            context.lineWidth = 1;
            context.strokeStyle = "yellow";
            
            let t=0;
            let l=0;
            let w=0;
            let h=0;        
            if (imageWidth>imageHeight){                
              let imageHeightInCanvas=(canvasWidth*imageHeight)/imageWidth;
              l=inferences.objects[i].rectangle.x*canvasWidth/imageWidth;
              t=inferences.objects[i].rectangle.y*canvasHeight/imageHeight+(canvasHeight-imageHeightInCanvas)/2;
              w=inferences.objects[i].rectangle.w*canvasWidth/imageWidth;
              h=inferences.objects[i].rectangle.h*imageHeightInCanvas/imageHeight;      
            }
            else{

              let imageWidthInCanvas=((canvasHeight*imageWidth)/imageHeight);
              l=(inferences.objects[i].rectangle.x*imageWidthInCanvas/imageWidth)+(canvasWidth-imageWidthInCanvas)/2;
              t=inferences.objects[i].rectangle.y*canvasHeight/imageHeight;
              w=inferences.objects[i].rectangle.w*imageWidthInCanvas/imageWidth;
              h=inferences.objects[i].rectangle.h*canvasHeight/imageHeight;       
            }
            context.moveTo(l,t);
            context.lineTo(l+w,t);
            context.lineTo(l+w,t+h);
            context.lineTo(l,t+h);
            context.lineTo(l,t);

            const fontSize = 20;
            context.font = `${fontSize}px Verdana`;
            context.fillStyle = "yellow";

            if(t-fontSize-fontSize/2>0)
              context.fillText(inferences.objects[i].object,
                l, 
                t-fontSize/2);
            else
              context.fillText(inferences.objects[i].object,
                l, 
                t+h+fontSize+fontSize/2);

            context.stroke();
          }
      }
      context.closePath();
    }
  }  
  drawCustomVisionRects(context:CanvasRenderingContext2D,inferences:CustomVisionInferences, canvasWidth:number, canvasHeight:number, imageWidth:number, imageHeight:number){
    if(inferences)
    {
      for(let i = 0; i < inferences.predictions.length; i++){
        if((inferences.predictions[i].tagName)&&
          (inferences.predictions[i].probability>0)){
              
            context.beginPath();
            context.lineWidth = 1;
            context.strokeStyle = "yellow";
            
            let t=0;
            let l=0;
            let w=0;
            let h=0;            
            l=inferences.predictions[i].boundingBox.left*canvasWidth;
            t=inferences.predictions[i].boundingBox.top*canvasHeight;
            w=inferences.predictions[i].boundingBox.width*canvasWidth;
            h=inferences.predictions[i].boundingBox.height*canvasHeight;       

            context.moveTo(l,t);
            context.lineTo(l+w,t);
            context.lineTo(l+w,t+h);
            context.lineTo(l,t+h);
            context.lineTo(l,t);

            const fontSize = 20;
            context.font = `${fontSize}px Verdana`;
            context.fillStyle = "yellow";

            if(t-fontSize-fontSize/2>0)
              context.fillText(inferences.predictions[i].tagName,
                l, 
                t-fontSize/2);
            else
              context.fillText(inferences.predictions[i].tagName,
                l, 
                t+h+fontSize+fontSize/2);

            context.stroke();
          }
      }
      context.closePath();
    }
  }  
  drawYoloRects(context:CanvasRenderingContext2D,inferences:YoloInferences, canvasWidth:number, canvasHeight:number, imageWidth:number, imageHeight:number){
    if((inferences)&&(inferences.inferences))
    {
      for(let i = 0; i < inferences.inferences.length; i++){
        if((inferences.inferences[i].entity)&&
          (inferences.inferences[i].entity.tag)){
            
            context.beginPath();
            context.lineWidth = 1;
            context.strokeStyle = "yellow";
            
            let t=0;
            let l=0;
            let w=0;
            let h=0;            
            if (imageWidth>imageHeight){
              l=inferences.inferences[i].entity.box.l*canvasWidth;
              t=inferences.inferences[i].entity.box.t*canvasWidth - (canvasWidth-canvasHeight)/2;
              w=inferences.inferences[i].entity.box.w*canvasWidth;
              h=inferences.inferences[i].entity.box.h*canvasWidth;                
            }
            else
            {
              l=inferences.inferences[i].entity.box.l*canvasHeight - (canvasHeight-canvasWidth)/2;
              t=inferences.inferences[i].entity.box.t*canvasHeight;
              w=inferences.inferences[i].entity.box.w*canvasHeight;
              h=inferences.inferences[i].entity.box.h*canvasHeight;                  
            }

            context.moveTo(l,t);
            context.lineTo(l+w,t);
            context.lineTo(l+w,t+h);
            context.lineTo(l,t+h);
            context.lineTo(l,t);

            const fontSize = 20;
            context.font = `${fontSize}px Verdana`;
            context.fillStyle = "yellow";

            if(t-fontSize-fontSize/2>0)
              context.fillText(inferences.inferences[i].entity.tag.value,
                l, 
                t-fontSize/2);
            else
              context.fillText(inferences.inferences[i].entity.tag.value,
                l, 
                t+h+fontSize+fontSize/2);

            context.stroke();
          }
      }
      context.closePath();
    }
    else
    {
      context.beginPath();    
      const fontSize = 40;
      context.font = `${fontSize}px Verdana`;
      context.fillStyle = "red";

      let t=2*fontSize;
      let l=canvasWidth/2 - 8*fontSize;            
      context.fillText("No object detected",
        l, 
        t-fontSize/2);
      context.stroke();
      context.closePath();

    }
  }  
  loadObjects(frameUri: string): Promise<string | null> {
    return new Promise<string | null>((resolve, reject) => {
      (async () => {
        const objectUri = frameUri.replace('.jpg','.json');
        try {
          var response = await this.callAPIAsync("GET",objectUri,this.storageClient.getStorageToken(),null);
          if (response) {
            if (response.status == 200) {
              //const dubcard: Dubcard = await response.json() as Dubcard;
              const result = await response.text();
              if(result.length>0)
                resolve(result);
              else
                resolve("{}");
            }
            else if (response.status == 404) {
              resolve("{}");
            }
            else
              reject(`Exception while reading json file response uri: ${objectUri} status: ${response.status} `)
          }
          else
            reject(`Exception while reading json return null uri: ${objectUri} `)
        }
        catch (e) {
          reject(`Exception while reading json return null uri: ${objectUri} Exception ${e}`);
        }
      })();
    });
  }
  /**
   * Returns image dimensions for specified URL.
   */
  getImageDimensions = (url: string): Promise<{image: HTMLImageElement, width: number, height: number}> => {
    return new Promise((resolve, reject) => {
      const img:HTMLImageElement = document.createElement("img");
      img.onload = () => resolve({
        image: img,
        width: img.width,
        height: img.height,
      });
      img.onerror = (error) => reject(error);
      img.src = url;
    });
  };
  displayFrame(){
      let playDiv = (<HTMLDivElement>document.getElementById("playImageDiv"));
      let canvas = (<HTMLCanvasElement>document.getElementById("playImageCanvas"));
      if((canvas)&&(playDiv)){
      
      canvas.setAttribute("style", `background-image:url('${this.returnedBlobUrls[this.returnedBlobUrlIndex]}?${globalConfiguration.storageAccountResultSASToken}');background-repeat:no-repeat;background-position:center;background-size:contain;`);

      this.getImageDimensions(`${this.returnedBlobUrls[this.returnedBlobUrlIndex]}?${globalConfiguration.storageAccountResultSASToken}`).then((value: {image: HTMLImageElement, width: number, height: number}) => {
     
        var context = canvas.getContext("2d");
        if(context){
          context.clearRect(0, 0, canvas.width, canvas.height);
          this.loadObjects(this.returnedBlobUrls[this.returnedBlobUrlIndex]).then((jsonString) => {
            if(context)
              this.drawRects(context,jsonString,canvas.width, canvas.height, value.width,value.height);
          });
        }
      });

    }
  }
  playPrev(){
    this.returnedBlobUrlIndex = this.returnedBlobUrlIndex - 1;
    if(this.returnedBlobUrlIndex < 0)
      this.returnedBlobUrlIndex = 0;
    this.displayFrame();
    this.updatePlayControls();  
  }
  playNext(){
    this.returnedBlobUrlIndex = this.returnedBlobUrlIndex + 1;
    if(this.returnedBlobUrlIndex > (this.returnedBlobUrls.length-1))
      this.returnedBlobUrlIndex = this.returnedBlobUrls.length-1;
      this.displayFrame();
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
    var waiting = new PageWaiting("resultWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading Slots"));
    try
    {
      const uriCombo = (<HTMLSelectElement>document.getElementById("resultListCamera"));
      if (uriCombo) {
        if((uriCombo.options.selectedIndex >= 0)&&
        (uriCombo.options.selectedIndex <= (this.cameraList.length-1)))
        {
          this.cameraIndex = uriCombo.options.selectedIndex;
          await this.getListBlobs(`${this.storageFolder}/${this.cameraList[this.cameraIndex]}`);
          this.fillSlotCombo("resultListSlot",this.getSlotList(this.cameraList[this.cameraIndex]));
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
    var waiting = new PageWaiting("resultWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading blobs"));
    try
    {
      const uriCombo = (<HTMLSelectElement>document.getElementById("resultListSlot"));
      if (uriCombo) {
        if((uriCombo.options.selectedIndex >= 0)&&
        (uriCombo.options.selectedIndex <= (this.slotList.length-1)))
        {
          this.slotIndex = uriCombo.options.selectedIndex;
          await this.getListBlobs(`${this.storageFolder}/${this.cameraList[this.cameraIndex]}/${this.slotList[this.slotIndex]}`);
          this.fillFrameCombo("resultListUri",this.returnedBlobUrls);
        }
      }    
      this.displayFrame();
      this.updatePlayControls();
    }
    catch(e){
    }
    finally{
      waiting.hide();  
    }
  }

  currentFrameChange(){
    var waiting = new PageWaiting("resultWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Playing blobs"));
    try
    {
      const uriCombo = (<HTMLSelectElement>document.getElementById("resultListUri"));
      if (uriCombo) {
        if((uriCombo.options.selectedIndex >= 0)&&
        (uriCombo.options.selectedIndex <= (this.returnedBlobUrls.length-1)))
        {
          this.returnedBlobUrlIndex = uriCombo.options.selectedIndex;
        }
      }    
      this.displayFrame();
      this.updatePlayControls();
    }
    catch(e){
    } 
    finally{
      waiting.hide();  
    } 
  }

  static StaticPlay() {
    if (ResultPage.current)
    ResultPage.current.playCarousel();
  }   
  static StaticPrev() {
    if (ResultPage.current)
    ResultPage.current.playPrev();
  }   
  static StaticNext() {
    if (ResultPage.current)
    ResultPage.current.playNext();
  }   
  static StaticCurrentCameraChange() {
    if (ResultPage.current)
    ResultPage.current.currentCameraChange();
  }   
  static StaticCurrentSlotChange() {
    if (ResultPage.current)
    ResultPage.current.currentSlotChange();
  }   
  static StaticCurrentFrameChange() {
    if (ResultPage.current)
    ResultPage.current.currentFrameChange();
  }   
  updatePlayControls() {
    const prevButton = (<HTMLButtonElement>document.getElementById("resultPrev"));
    if (prevButton) {
      if(this.returnedBlobUrlIndex == 0)
        prevButton.disabled = true;
      else
        prevButton.disabled = false;
    }
    const nextButton = (<HTMLButtonElement>document.getElementById("resultNext"));
    if (nextButton) {
      if(this.returnedBlobUrlIndex == (this.returnedBlobUrls.length-1))
        nextButton.disabled = true;
      else
        nextButton.disabled = false;
    }
    const uriCombo = (<HTMLSelectElement>document.getElementById("resultListUri"));
    if (uriCombo) {
      uriCombo.options.selectedIndex = this.returnedBlobUrlIndex;
    }
  }

  registerEvents(): boolean {
    this.logClient.log("ResultPage registerEvents");

    super.addEvent("resultPlay", "click", ResultPage.StaticPlay);
    super.addEvent("resultPrev", "click", ResultPage.StaticPrev);
    super.addEvent("resultNext", "click", ResultPage.StaticNext);
    super.addEvent("resultListCamera", "change", ResultPage.StaticCurrentCameraChange); 
    super.addEvent("resultListSlot", "change", ResultPage.StaticCurrentSlotChange); 
    super.addEvent("resultListUri", "change", ResultPage.StaticCurrentFrameChange); 
    return true;
  }

  unregisterEvents(): boolean {
    this.logClient.log("ResultPage unregisterEvents");

    super.removeEvent("resultPlay", "click", ResultPage.StaticPlay);
    super.removeEvent("resultPrev", "click", ResultPage.StaticPrev);
    super.removeEvent("resultNext", "click", ResultPage.StaticNext);   
    super.removeEvent("resultListCamera", "change", ResultPage.StaticCurrentCameraChange); 
    super.removeEvent("resultListSlot", "change", ResultPage.StaticCurrentSlotChange); 
    super.removeEvent("resultListUri", "change", ResultPage.StaticCurrentFrameChange); 
    return true;
  }


  onInitializePage(): boolean {
    var waiting = new PageWaiting("resultWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading blob records"));
    this.addHTMLValueMap([
      { id: "resultPageTitle",  value: globalThis.globalVars.getCurrentString("Results Page"), readonly: true },
    ]);
    this.updateData(false);
    // Initialize Page  
    this.fillCameraCombo("resultListCamera",this.cameraList);

    /*
    this.getListBlobs(this.storageFolder,this.cameraList)
      .then((count) => {
        this.logMessage(`${count} frame record(s) in results table`);
        this.fillFrameCombo("resultListUri",this.returnedBlobUrls);
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
let localPage = new ResultPage("content", "Home", "result.html", null,
  globalThis.globalConfiguration.version,
  globalThis.globalClient.getLogClient(),
  globalThis.globalClient.getStorageResultClient(),
  globalThis.globalClient.getStorageFolder(),
  globalThis.globalClient.getCameraList());
  
if (localPage) {
  
  localPage.initializePage();
}

