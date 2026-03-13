
import { AlertData } from '../models/AlertData';

interface TemplateData {
  typeName: string;
  msg: string;
  level: string;
}

export class AlertSyncService {
  private static instance: AlertSyncService;
  private alerts: AlertData[] = [];
  private initialized: boolean = false;
  private newAlertIds: string[] = [];
  private videoEnterCount: number = 0;

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
    this.alerts = [
      {
        alert_id: 'AL_001',
        type: 'temp_high',
        type_name: '高温异常',
        level: 'critical',
        timestamp: 1710200000000,
        message: '气温持续高于32°C(最高达35.3°C)，超出番茄适宜生长温度范围(25-28°C)，可能导致植株热胁迫、落花落果。',
        source: 'environment',
        source_name: '环境监测',
        is_handled: false,
        handle_time: null
      },
      {
        alert_id: 'AL_002',
        type: 'pest_warning',
        type_name: '病害预警',
        level: 'warning',
        timestamp: 1710100000000,
        message: '视觉检测连续识别到番茄早疫病(置信度0.9-0.98)，高湿环境可能加速病害扩散，需立即干预。',
        source: 'environment',
        source_name: '环境监测',
        is_handled: true,
        handle_time: 1710105000000
      },
      {
        alert_id: 'AL_003',
        type: 'humidity_low',
        type_name: '空气湿度过低',
        level: 'info',
        timestamp: 1710000000000,
        message: '气湿最低至41.7%，低于番茄生长适宜湿度(60-70%)，可能加剧蒸腾作用与水分胁迫。',
        source: 'environment',
        source_name: '环境监测',
        is_handled: false,
        handle_time: null
      },
      {
        alert_id: 'AL_004',
        type: 'moisture_low',
        type_name: '土壤湿度偏低',
        level: 'warning',
        timestamp: 1709900000000,
        message: '土湿仅18.5%-20.5%，低于番茄生长适宜阈值(约25-30%)，需关注灌溉系统是否正常。',
        source: 'environment',
        source_name: '环境监测',
        is_handled: false,
        handle_time: null
      },
      {
        alert_id: 'AL_005',
        type: 'equipment_offline',
        type_name: '设备未响应环境异常',
        level: 'critical',
        timestamp: 1709800000000,
        message: '系统处于自动模式，但高温、低湿条件下风扇与水泵均未启动，可能存在控制逻辑或执行器故障。',
        source: 'system',
        source_name: '系统诊断',
        is_handled: false,
        handle_time: null
      }
    ];
  }

  public getAllAlerts(): AlertData[] {
    this.ensureInitialized();
    return [...this.alerts];
  }

  public addRuntimeAlert(alert: AlertData) {
    this.ensureInitialized();
    const exists = this.alerts.some((item: AlertData) => item.alert_id === alert.alert_id);
    if (exists) {
      return;
    }

    this.alerts = [alert, ...this.alerts];
    this.newAlertIds = [alert.alert_id, ...this.newAlertIds];
  }

  public simulateVideoAnomaliesOnEnter(deviceId: string) {
    this.ensureInitialized();
    this.videoEnterCount += 1;

    const addByEnter: Record<number, number> = {
      1: 2,
      2: 1,
      3: 2
    };

    const addCount = addByEnter[this.videoEnterCount] || 0;
    if (addCount === 0) {
      return;
    }

    const now = new Date().getTime();
    const templates: TemplateData[] = [
      { typeName: '视频异常-叶片病斑', msg: 'AI检测到叶片病斑，建议立即巡检叶片状态。', level: 'warning' },
      { typeName: '视频异常-人员闯入', msg: 'AI检测到非作业时段人员闯入，请及时确认。', level: 'critical' },
      { typeName: '视频异常-灌溉渗漏', msg: 'AI检测到灌溉区域疑似渗漏，请检查管路。', level: 'warning' },
      { typeName: '视频异常-果实霉斑', msg: 'AI检测到果实疑似霉斑，请尽快排查。', level: 'warning' }
    ];

    for (let i = 0; i < addCount; i++) {
      const tpl = templates[(this.videoEnterCount + i - 1) % templates.length];
      this.addRuntimeAlert({
        alert_id: `VA_${deviceId}_${this.videoEnterCount}_${i}`,
        type: 'video_abnormal',
        type_name: tpl.typeName,
        level: tpl.level,
        timestamp: now - i * 30000,
        message: tpl.msg,
        source: 'video',
        source_name: '视频AI',
        is_handled: false,
        handle_time: null
      });
    }
  }

  public consumeNewAlertsForDialog(): AlertData[] {
    this.ensureInitialized();
    if (this.newAlertIds.length === 0) {
      return [];
    }

    const ids = [...this.newAlertIds];
    this.newAlertIds = [];
    return ids
      .map((id: string) => this.alerts.find((item: AlertData) => item.alert_id === id))
      .filter((item: AlertData | undefined) => item !== undefined) as AlertData[];
  }

  public markHandled(alertId: string) {
    this.ensureInitialized();
    const target = this.alerts.find((item: AlertData) => item.alert_id === alertId);
    if (target) {
      target.is_handled = true;
      target.handle_time = new Date().getTime();
      this.alerts = [...this.alerts];
    }
  }
}
