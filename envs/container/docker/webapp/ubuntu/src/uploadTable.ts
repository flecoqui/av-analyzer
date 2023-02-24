import { IDialog, EndDialogCallback } from "./idialog";
import { isNullOrUndefinedOrEmpty, isNullOrUndefined, getFileContentAsync } from "./common";

/**
 * uploadTable
 */
export class UploadTable  {
  tableId: string = "";
  columns: Array<string> = [];
  nofilemessage: string = "";
  constructor(id: string ) {
    this.tableId = id;
  }


  createHeaders():boolean {
    var table = document.getElementById(this.tableId);
    if (table == null)
      return false;
    if (this.columns == null)
      return false;

    while (table.hasChildNodes()) {
      if (table.firstChild != null)
        table.removeChild(table.firstChild);
    }
    // create header
    var tableHeader = document.createElement('THEAD');
    table.appendChild(tableHeader);
    var trHeader = document.createElement('TR');
    tableHeader.appendChild(trHeader);
    for (var i = 0; i < this.columns.length; i++) {
      var th = document.createElement('TH');
      th.appendChild(document.createTextNode(this.columns[i]));
      trHeader.appendChild(th);
    }
    // fill data
    var tableBody = document.createElement('TBODY');
    table.appendChild(tableBody);
    return true;
  };
  create(columns: Array<string>, nofilemessage: string){
    this.columns = columns;
    this.nofilemessage = nofilemessage;
    this.addFiles(null);
  }
  addFiles(files: FileList|null):boolean {
    // Create Headers
    this.createHeaders();

    var table = document.getElementById(this.tableId);
    if (table == null)
      return false;
    var collection:HTMLCollectionOf<Element> = table.getElementsByTagName('TBODY');      
    if((collection==null)||(collection.length == 0))
      return false;
    var tableBody:HTMLElement = collection[0] as HTMLElement; 

    if (files != null){
      for (var i = 0; i < files.length; i++) {
        var trBody = document.createElement('TR');
        tableBody.appendChild(trBody);
        var tdbpath = document.createElement('TD');
        var filePath = files[i].name;
        tdbpath.appendChild(document.createTextNode(filePath));
        trBody.appendChild(tdbpath);
        var tdbsize = document.createElement('TD');
        tdbsize.appendChild(document.createTextNode(files[i].size.toString()));
        trBody.appendChild(tdbsize);
        var tdbstatus = document.createElement('TD');

        var divProgress = document.createElement("div");
        divProgress.className = "progress";
        var divProgressBar = document.createElement("div");
        divProgressBar.className = "progress-bar";
        divProgressBar.classList.add("mini-background-color");
        divProgressBar.innerHTML = "0%";
        divProgressBar.id = "divprogressbar" + i;
        divProgress.appendChild(divProgressBar);
        tdbstatus.appendChild(divProgress);
        trBody.appendChild(tdbstatus);
      }
    }
    else
    {
      // Add empty line
      var trBody = document.createElement('TR');
      tableBody.appendChild(trBody);
      var tdbpath = document.createElement('TD');
      tdbpath.appendChild(document.createTextNode(this.nofilemessage));
      trBody.appendChild(tdbpath);
      var tdbsize = document.createElement('TD');
      tdbsize.appendChild(document.createTextNode(""));
      trBody.appendChild(tdbsize);
      var tdbstatus = document.createElement('TD');
      var divProgress = document.createElement("div");
      tdbstatus.appendChild(divProgress);
      trBody.appendChild(tdbstatus);

    }
    return true;
  };
  getProgressBar(path: string): ChildNode|null {
    var table = (<HTMLTableElement>document.getElementById(this.tableId));
    if ((table !== null) && (table !== undefined)) {
      var body = table.tBodies[0];
      var rows = table.rows;

      for (var i = rows.length - 1; i >= 0; i--) { 
        var cols = rows[i].cells;
        if (cols.length >= 3) {
          if ((<Text>cols[0].childNodes[0]).wholeText === path) {
            var c = cols[2].firstChild;
            if ((c !== null) && (c !== undefined)) {
              return c.firstChild;
            }
          }
        }
      }
    }
    return null;
  };
  setProgressValue(path: string, progress: number ): boolean {
    var control: HTMLElement = <HTMLElement>this.getProgressBar(path);
    progress = Math.ceil(progress)
    if ((control !== null) && (control !== undefined)) {
      if (progress >= 0)
        control.style.width = progress + "%";
      control.innerHTML = progress + "%";
      return true;
    }
    return false;
  };
}
