
import { AlertData } from '../models/AlertData';
import { AlertListItem, HttpService } from './HttpService';
import { MqttClientService } from './MqttClientService';

/**
 * Purpose: 聚合告警的启动加载、实时推送和本地处理状态，向多个页面提供同一份告警内存态。
 * Responsibilities: 维护告警列表、合并 HTTP 与 MQTT 来源、广播数据变化，并控制全局告警弹窗显示时机。
 * Flow: 首次 startRealtimeSync() 时注册 MQTT 告警监听并触发启动批量加载；后续所有更新都统一走 mergeAlert()。
 * Dependencies: 依赖 HttpService 获取启动告警和处理告警，依赖 MqttClientService 接收实时告警。
 * Input: MQTT alert payload、告警列表接口返回值和用户的处理操作。
 * Output: 排序后的 AlertData 列表、数据变化通知和全局告警弹窗回调。
 * Invariant: 告警只以 alert_id 去重；所有来源写入都必须经过 mergeAlert()，避免列表和弹窗策略分叉。
 */
interface AlertPushPayload {
  msg_type?: string;
  node_id?: string;
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
  private onAlertPush = (_nodeId: string, msgStr: string) => {
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

    // Flow: 启动实时同步时同时补一轮历史告警，确保列表页不会只看到“进入页面之后”产生的告警。
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
    // Reason: 新告警与已存在告警都走同一路径，这样 HTTP 启动同步和 MQTT 实时推送才能共享去重、排序和通知策略。
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

    // Boundary: 启动阶段固定拉取最近 200 条并只做一次，避免每次切换回告警页都重复打接口或反复插入旧数据。
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

  private alertDialogCallback: ((alert: AlertData) => void) | null = null;

  public setAlertDialogCallback(cb: (alert: AlertData) => void) {
    this.alertDialogCallback = cb;
  }

  public markDialogClosed() {
    this.isDialogShowing = false;
  }

  private showGlobalAlert(alert: AlertData) {
    // Boundary: 未登录或当前正处于告警 Tab 时不弹窗，避免重复打断用户正在查看的内容。
    if (this.isDialogShowing) return;
    const isLoggedIn = AppStorage.get<boolean>('isLoggedIn');
    if (!isLoggedIn) return;
    const currentTabIndex = AppStorage.get<number>('currentTabIndex');
    if (currentTabIndex === 1) return;

    this.isDialogShowing = true;
    if (this.alertDialogCallback) {
      this.alertDialogCallback(alert);
    } else {
      this.isDialogShowing = false;
    }
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
