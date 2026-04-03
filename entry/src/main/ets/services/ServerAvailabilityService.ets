import { HttpService } from './HttpService';

export enum ServerAvailabilityMode {
  STARTUP = 'startup',
  SESSION = 'session'
}

export class ServerAvailabilityService {
  private static instance: ServerAvailabilityService;
  private static readonly STARTUP_INTERVAL_MS: number = 5000;
  private static readonly SESSION_INTERVAL_MS: number = 2000;
  private static readonly SESSION_FAILURE_THRESHOLD: number = 2;

  private timerId: number = -1;
  private available: boolean = true;
  private consecutiveFailures: number = 0;
  private statusListeners: Array<(available: boolean) => void> = [];
  private forceLogoutListeners: Array<() => void> = [];

  private constructor() {
  }

  public static getInstance(): ServerAvailabilityService {
    if (!ServerAvailabilityService.instance) {
      ServerAvailabilityService.instance = new ServerAvailabilityService();
    }
    return ServerAvailabilityService.instance;
  }

  public isServerAvailable(): boolean {
    return this.available;
  }

  public getConsecutiveFailures(): number {
    return this.consecutiveFailures;
  }

  public addStatusListener(listener: (available: boolean) => void): void {
    if (this.statusListeners.indexOf(listener) === -1) {
      this.statusListeners.push(listener);
    }
  }

  public removeStatusListener(listener: (available: boolean) => void): void {
    const index = this.statusListeners.indexOf(listener);
    if (index >= 0) {
      this.statusListeners.splice(index, 1);
    }
  }

  public addForceLogoutListener(listener: () => void): void {
    if (this.forceLogoutListeners.indexOf(listener) === -1) {
      this.forceLogoutListeners.push(listener);
    }
  }

  public removeForceLogoutListener(listener: () => void): void {
    const index = this.forceLogoutListeners.indexOf(listener);
    if (index >= 0) {
      this.forceLogoutListeners.splice(index, 1);
    }
  }

  public recordHealthResult(available: boolean, mode: ServerAvailabilityMode): boolean {
    const oldAvailable = this.available;
    this.available = available;

    if (available) {
      this.consecutiveFailures = 0;
    } else {
      this.consecutiveFailures += 1;
    }

    if (oldAvailable !== this.available) {
      this.notifyStatusChanged(this.available);
    }

    const shouldForceLogout =
      mode === ServerAvailabilityMode.SESSION &&
      !available &&
      this.consecutiveFailures >= ServerAvailabilityService.SESSION_FAILURE_THRESHOLD;

    if (shouldForceLogout) {
      this.notifyForceLogout();
      this.consecutiveFailures = 0;
    }

    return shouldForceLogout;
  }

  public async retryNow(mode: ServerAvailabilityMode): Promise<boolean> {
    const available = await HttpService.getInstance().checkServerHealth();
    this.recordHealthResult(available, mode);
    return available;
  }

  public async startStartupPolling(intervalMs: number = ServerAvailabilityService.STARTUP_INTERVAL_MS): Promise<boolean> {
    return this.startPolling(ServerAvailabilityMode.STARTUP, intervalMs);
  }

  public async startSessionMonitoring(intervalMs: number = ServerAvailabilityService.SESSION_INTERVAL_MS): Promise<boolean> {
    return this.startPolling(ServerAvailabilityMode.SESSION, intervalMs);
  }

  public stopPolling(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  public resetForTest(): void {
    this.stopPolling();
    this.available = true;
    this.consecutiveFailures = 0;
    this.statusListeners = [];
    this.forceLogoutListeners = [];
  }

  private async startPolling(mode: ServerAvailabilityMode, intervalMs: number): Promise<boolean> {
    this.stopPolling();
    const first = await this.retryNow(mode);
    this.timerId = setInterval(() => {
      void this.retryNow(mode);
    }, intervalMs);
    return first;
  }

  private notifyStatusChanged(available: boolean): void {
    this.statusListeners.forEach((listener) => listener(available));
  }

  private notifyForceLogout(): void {
    this.forceLogoutListeners.forEach((listener) => listener());
  }
}