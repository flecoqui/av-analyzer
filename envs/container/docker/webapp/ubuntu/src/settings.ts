import './globalconfig';
import { isNullOrUndefined } from "./common";
import { Page } from "./page";

class SettingsPage extends Page {
  version: string;
  constructor(id: string, name: string, uri: string | null, content: string | null, version: string) {
    super(id, name, uri, content);
    this.version = version;
  }
  
  registerEvents(): boolean {
    if (super.registerEvents)
      super.registerEvents();
    super.addEvent("colorselection", "change", (ev: any) => { this.updateData(true); });
    super.addEvent("languageselection", "change", (ev: any) => { this.updateData(true); });
    super.addEvent("paginationsizeselection", "change", (ev: any) => { this.updateData(true); });
    super.addEvent("navigationcache", "click", (ev: any) => { this.updateData(true); });
    super.addEvent("configurationtab", "click", (ev: any) => { this.UpdateTabBar("configurationtab"); });
    super.addEvent("cloudtab", "click", (ev: any) => { this.UpdateTabBar("cloudtab"); });
    super.addEvent("favoritetab", "click", (ev: any) => { this.UpdateTabBar("favoritetab"); });
    super.addEvent("devicetab", "click", (ev: any) => { this.UpdateTabBar("devicetab"); });
    return true;
  };

  unregisterEvents(): boolean {
    if (super.unregisterEvents)
      super.unregisterEvents();
    super.removeEvent("colorselection", "change", (ev: any) => { this.updateData(true); });
    super.removeEvent("languageselection", "change", (ev: any) => { this.updateData(true); });
    super.removeEvent("paginationsizeselection", "change", (ev: any) => { this.updateData(true); });
    super.removeEvent("navigationcache", "click", (ev: any) => { this.updateData(true); });
    super.removeEvent("configurationtab", "click", (ev: any) => { this.UpdateTabBar("configurationtab"); });
    super.removeEvent("cloudtab", "click", (ev: any) => { this.UpdateTabBar("cloudtab"); });
    super.removeEvent("favoritetab", "click", (ev: any) => { this.UpdateTabBar("favoritetab"); });
    super.removeEvent("devicetab", "click", (ev: any) => { this.UpdateTabBar("devicetab"); });
    return true;
  };
  onUpdate(update: boolean): void {
    if (update == true) {
      let color = this.getHTMLValue('colorselection');
      if (color) {
        let oldcolor = globalThis.globalVars.getGlobalColor();
        if (color.value != oldcolor) {
          globalThis.globalVars.setGlobalColor(String(color.value));
          document.documentElement.setAttribute('theme', String(color.value));
          window.location.reload();
        }
      }
      let language = this.getHTMLValue('languageselection');
      if (language) {
        let oldlanguage = globalThis.globalVars.getGlobalLanguage();
        if (language.value != oldlanguage) {
          globalThis.globalVars.setGlobalLanguage(String(language.value));
          window.location.reload();
        }
      }
      
      let paginationsize = this.getHTMLValue('paginationsizeselection');
      if (paginationsize) {
        let oldpaginationsize = globalThis.globalVars.getGlobalPageSize();
        if (paginationsize.value != oldpaginationsize) {
          globalThis.globalVars.setGlobalPageSize(Number.parseInt(paginationsize.value.toString()));
        }
      }

      let cache = this.getHTMLValue('navigationcache');
      if (cache) {
        let oldcache = globalThis.globalVars.getGlobalCache();
        if (cache.value != oldcache) {
          globalThis.globalVars.setGlobalCache(JSON.parse(cache.value.toString()));
        }
      }            
    }
  }
  UpdateTabBar(id: string) {
    var array: string[] = ["cloudtab", "favoritetab", "devicetab", "configurationtab"];
    for (var index: number = 0; index < array.length; index++) {
      var menu: HTMLAnchorElement = document.getElementById(array[index]) as HTMLAnchorElement;
      if (!isNullOrUndefined(menu)) {
        if (id == array[index]) {
          menu.style.backgroundColor = getComputedStyle(document.documentElement)
            .getPropertyValue('--mini-button-bg-color'); // #999999
          menu.style.color = getComputedStyle(document.documentElement)
            .getPropertyValue('--mini-button-text-color'); // #999999
        }
        else {
          menu.style.backgroundColor = 'Transparent';
          menu.style.color = getComputedStyle(document.documentElement)
            .getPropertyValue('--mini-button-bg-color'); // #999999
        }
      };
    }
  }
  onInitializePage(): boolean {
    this.addHTMLValueMap([
      { id: "versionButton",  value: this.version, readonly: true },
      { id: "languageselection", value: globalThis.globalVars.getGlobalLanguage(), readonly: false  },
      { id: "paginationsizeselection", value: globalThis.globalVars.getGlobalPageSize(), readonly: false  },
      { id: "colorselection", value: globalThis.globalVars.getGlobalColor(), readonly: false  },
      { id: "navigationcache", value: globalThis.globalVars.getGlobalCache(), readonly: false  },
    ]);

    this.updateData(false);
    // Update Tab
    this.UpdateTabBar("configurationtab");
    return true;
  }

}

let localPage = new SettingsPage("content", "Settings", "settings.html", null, globalThis.globalConfiguration.version);
if (localPage) {
  // Initialize Page  
  localPage.initializePage();
}

