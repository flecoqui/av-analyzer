export function stringFormat(str: string, ...val: string[]) {
  for (let index = 0; index < val.length; index++) {
    str = str.replace(`{${index}}`, val[index]);
  }
  return str;
}

// check if value is null, undefined
export function isNullOrUndefined(value: any) {
  if ((value === null) || (value === undefined))
    return true;
  return false;
};

// check if value is null, undefined or empty
export function isNullOrUndefinedOrEmpty(value: any) {
  if ((value === null) || (value === undefined))
    return true;
  if (value == "")
    return true;
  return false;
};

// Open file on internet argument: uri
export async function getFileAsync(uri: string) {
  const p = new Promise<string>(resolve => getFileAsyncFunction(resolve, uri));
  const result = await p;
  return result;
};

var getFileAsyncFunction = function (resolve: any, uri: string) {
  let req = new XMLHttpRequest()
  req.open('GET', uri, true)
  req.onreadystatechange = function (aEvt) {
    if (req.readyState == 4) {
      if (req.status == 200)
        resolve(req.responseText)
      else
        resolve(null)
    }
  };
  req.send(null)
};

export var isEmpty = function (str: string) {
  return !str || 0 === str.length;
};

export var getFileContentAsync = function (url: string): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    try {
      // Create a new AJAX request for fetching the partial HTML file.
      var request = new XMLHttpRequest();

      // Call the callback with the content loaded from the file.
      request.onload = () => {
        resolve(request.responseText);
      };

      // Fetch the partial HTML file for the given fragment id.
      request.open("GET", url);
      request.setRequestHeader("Content-Type", "text/html; charset=utf-8");
      request.setRequestHeader("Cache-Control", "3600");
      request.send(null);
    }
    catch (e) {
      if (e instanceof Error)
        console.log(`Error while opening ${url}:  ${e.message}`);
      else
        console.log(`Error while opening ${url}:  ${String(e)}`);
      reject(null);
    }
  });
}

export class Guid {
  static newGuid() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      var r = Math.random() * 16 | 0,
        v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }
}