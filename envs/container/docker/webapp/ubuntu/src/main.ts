import './globalconfig';
import './globalclient';
import { isNullOrUndefinedOrEmpty, isNullOrUndefined, isEmpty } from "./common";
import { NavigationManager, PageConfiguration } from "./navmanager";

var manager: NavigationManager = new NavigationManager();

function openPage(nav: NavigationManager, pageId: string) {
  console.log(`Opening page: ${pageId}`)
  nav.selectPage(pageId);
}
const connectedPages: Array<string> = ["live","result","record","settings"];
const offlinePages: Array<string> = ["live", "result", "record","settings"];
function isPageVisible(nav: NavigationManager, pageId: string): boolean {
  if (offlinePages.includes(pageId)) {
    //console.log(`Page ${pageId} is visible`)
    return true;
  }
  return false;
}


var pageConfiguration: Array<PageConfiguration> = [
  {
    pageId: "live",
    pageTitle: "Live",
    pageHTMLUri: "live.html",
    pageJavascriptUri: "live-bundle.js",
    pageNavigateFunction: openPage,
    pageConditionFunction: isPageVisible
  },
  {
    pageId: "result",
    pageTitle: "Result",
    pageHTMLUri: "result.html",
    pageJavascriptUri: "result-bundle.js",
    pageNavigateFunction: openPage,
    pageConditionFunction: isPageVisible
  },
  {
    pageId: "record",
    pageTitle: "Record",
    pageHTMLUri: "record.html",
    pageJavascriptUri: "record-bundle.js",
    pageNavigateFunction: openPage,
    pageConditionFunction: isPageVisible
  },
  {
    pageId: "settings",
    pageTitle: "Settings",
    pageHTMLUri: "settings.html",
    pageJavascriptUri: "settings-bundle.js",
    pageNavigateFunction: openPage,
    pageConditionFunction: isPageVisible
  }
];

var result = manager.initialization(
  "navbarsExampleDefault",
  "mediaburgerbutton",
  "content",
  globalThis.globalVars.getGlobalLanguage(),
  globalThis.globalVars.getGlobalColor(),
  pageConfiguration
);

if (result == true) {
  manager.navigate();
}
else {
  console.log("Error while initializing navigation manager");
}
