export enum LogLevel {
  debug = 1,
  log,
  info,
  warn,
  error,
}

export class LogClient {
  logLevel: LogLevel = LogLevel.error;
  static getLogLevelFromString(s: string): LogLevel {
    var level: LogLevel = LogLevel.debug;
    if (s == "degug")
      level = LogLevel.debug;
    else if (s == "info")
      level = LogLevel.info;
    else if (s == "log")
      level = LogLevel.log;
    else if (s == "warn")
      level = LogLevel.warn;
    else if (s == "error")
      level = LogLevel.error;
    return level;
  }
  constructor(level: LogLevel) {
    this.logLevel = level;
  }
  getLogLevel(): LogLevel {
    return this.logLevel;
  }
  setLogLevel(level: LogLevel): void {
    this.logLevel = level;
  }
  logEnable(): boolean {
    return (this.logLevel <= LogLevel.log)
  };
  infoEnable(): boolean {
    return (this.logLevel <= LogLevel.info)
  };
  debugEnable(): boolean {
    return (this.logLevel <= LogLevel.debug)
  };
  warnEnable(): boolean {
    return (this.logLevel <= LogLevel.warn)
  };
  errorEnable(): boolean {
    return (this.logLevel <= LogLevel.error)
  };
  log(message: any): void {
    if (this.logEnable())
      console.log(message);
  }
  info(message: any): void {
    if (this.infoEnable())
      console.info(message);
  }
  debug(message: any): void {
    if (this.debugEnable())
      console.debug(message);
  }
  warn(message: any): void {
    if (this.warnEnable())
      console.warn(message);
  }
  error(message: any): void {
    if (this.errorEnable())
      console.error(message);
  }
}