
import { AlertData } from '../models/AlertData';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { AlertListItem, HttpService } from './HttpService';
import { MqttClientService } from './MqttClientService';

interface AlertPushPayload {
  msg_type?: string;
  device_id?: string;
  timestamp?: number;
  data?: AlertListItem;
}

export class AlertSyncService {
  private static instance: AlertSyncService;
  private alerts: AlertData[] = [];
  private initialized: boolean = false;
  private isDialogShowing: boolean = false;
  private realtimeStarted: boolean = false;
  private startupLoaded: boolean = false;
  private startupLoading: boolean = false;
  private dataChangeListeners: (() => void)[] = [];
  private onAlertPush = (_deviceId: string, msgStr: string) => {
    this.handleAlertPush(msgStr);
  };

  public static getInstance(): AlertSyncService {
    if (!AlertSyncService.instance) {
      AlertSyncService.instance = new AlertSyncService();
    }
    return AlertSyncService.instance;
  }

  private ensureInitialized() {
    if (this.initialized) {
      return;
    }

    this.initialized = true;
    this.alerts = [];
  }

  public getAllAlerts(): AlertData[] {
    this.ensureInitialized();
    return [...this.alerts];
  }

  public subscribeDataChange(listener: () => void) {
    if (this.dataChangeListeners.indexOf(listener) === -1) {
      this.dataChangeListeners.push(listener);
    }
  }

  public unsubscribeDataChange(listener: () => void) {
    this.dataChangeListeners = this.dataChangeListeners.filter(l => l !== listener);
  }

  private notifyDataChange() {
    this.dataChangeListeners.forEach(listener => listener());
  }

  public startRealtimeSync() {
    this.ensureInitialized();
    if (this.realtimeStarted) {
      return;
    }

    this.realtimeStarted = true;
    MqttClientService.getInstance().addAlertListener(this.onAlertPush);
    void this.loadStartupAlerts();
  }

  public stopRealtimeSync() {
    if (!this.realtimeStarted) {
      return;
    }

    this.realtimeStarted = false;
    MqttClientService.getInstance().removeAlertListener(this.onAlertPush);
  }

  private mergeAlert(alert: AlertData, shouldNotifyDialog: boolean, shouldNotifyDataChange: boolean = true): boolean {
    let changed = false;
    const index = this.alerts.findIndex((item: AlertData) => item.alert_id === alert.alert_id);
    if (index >= 0) {
      this.alerts[index] = alert;
      changed = true;
    } else {
      this.alerts = [alert, ...this.alerts];
      changed = true;
      if (shouldNotifyDialog) {
        this.showGlobalAlert(alert);
      }
    }

    if (changed) {
      this.alerts = [...this.alerts].sort((left: AlertData, right: AlertData) => right.timestamp - left.timestamp);
      if (shouldNotifyDataChange) {
        this.notifyDataChange();
      }
    }

    return changed;
  }

  private handleAlertPush(msgStr: string) {
    this.ensureInitialized();
    try {
      const payload = JSON.parse(msgStr) as AlertPushPayload;
      if (!payload.data || !payload.data.alert_id) {
        return;
      }

      const alert = this.convertApiAlert(payload.data);
      if (!alert.timestamp && payload.timestamp) {
        alert.timestamp = payload.timestamp;
      }
      this.mergeAlert(alert, true, true);
    } catch (error) {
      console.error('[AlertSyncService] Failed to parse alert push', error);
    }
  }

  private async loadStartupAlerts() {
    if (this.startupLoaded || this.startupLoading) {
      return;
    }

    this.startupLoading = true;
    const res = await HttpService.getInstance().getAlerts('startup', 1, 200, 'timestamp', 'desc', '', '');
    if (!res || !res.data) {
      this.startupLoading = false;
      return;
    }

    const items = res.data.items || [];
    let hasMergedChanges = false;
    items.forEach((item: AlertListItem) => {
      const converted = this.convertApiAlert(item);
      if (this.mergeAlert(converted, false, false)) {
        hasMergedChanges = true;
      }
    });

    if (hasMergedChanges) {
      this.notifyDataChange();
    }

    this.startupLoaded = true;
    this.startupLoading = false;
  }

  private convertApiAlert(item: AlertListItem): AlertData {
    let alert = new AlertData();
    alert.alert_id = item.alert_id;
    alert.type = item.type;
    alert.type_name = item.type_name;
    alert.level = item.level;
    alert.timestamp = item.timestamp;
    alert.message = item.message;
    alert.source = item.source;
    alert.source_name = item.source_name;
    alert.is_handled = item.is_handled;
    alert.handle_time = item.handle_time;
    return alert;
  }

  private showGlobalAlert(alert: AlertData) {
    if (this.isDialogShowing) return;
    const isLoggedIn = AppStorage.get<boolean>('isLoggedIn');
    if (!isLoggedIn) return;
    const currentTabIndex = AppStorage.get<number>('currentTabIndex');
    if (currentTabIndex === 1) return;
    
    this.isDialogShowing = true;
    promptAction.showDialog({
      title: '新告警提示',
      message: `检测到新告警（最新：${alert.type_name}），是否立即查看？`,
      buttons: [
        { text: '稍后处理', color: '#90A4AE' },
        { text: '立即查看', color: '#D84315' }
      ]
    }).then((res) => {
      this.isDialogShowing = false;
      if (res.index === 1) {
        AppStorage.setOrCreate('currentTabIndex', 1);
        router.pushUrl({ url: 'pages/Index' });
      }
    }).catch(() => {
      this.isDialogShowing = false;
    });
  }

  public async markHandled(alertId: string): Promise<boolean> {
    this.ensureInitialized();
    const success = await HttpService.getInstance().handleAlert(alertId, 'handle');
    if (!success) {
      return false;
    }

    const target = this.alerts.find((item: AlertData) => item.alert_id === alertId);
    if (target) {
      target.is_handled = true;
      target.handle_time = new Date().getTime();
      this.alerts = [...this.alerts];
      this.notifyDataChange();
    }
    return true;
  }
}
