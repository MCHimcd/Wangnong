import http from '@ohos.net.http';

const BASE_URL = 'http://127.0.0.1:8080';
const APP_ID = 'WN_APP_001';

export class ApiQueryPayload {
  sensor_type?: string;
  device_type?: string;
  time_range?: string;
}

export class ApiDataSettingsPayload {
  auto_irrigation?: boolean;
  auto_cooling?: boolean;
  temp_high_alert?: number;
  humid_low_alert?: number;
}

export class ApiDataPayload {
  automation?: ApiDataSettingsPayload;
  thresholds?: ApiDataSettingsPayload;
}

export class AppApiPayload {
  app_id: string = APP_ID;
  device_id: string = "";
  timestamp: number = 0;
  query?: ApiQueryPayload;
  data?: ApiDataPayload;
}

export class HttpService {
  private static instance: HttpService;
  private currentDeviceId: string = "A03_Node_01";

  private constructor() {
  }

  public static getInstance(): HttpService {
    if (!HttpService.instance) {
      HttpService.instance = new HttpService();
    }
    return HttpService.instance;
  }

  public setDeviceId(id: string) {
    this.currentDeviceId = id;
  }

  private async postRequest(path: string, payload: AppApiPayload): Promise<Record<string, Object> | null> {
    let httpRequest = http.createHttp();
    let url = `${BASE_URL}${path}`;

    payload.app_id = APP_ID;
    payload.device_id = this.currentDeviceId;
    payload.timestamp = new Date().getTime();

    console.info(`[HttpService] POST ${url} payload: ${JSON.stringify(payload)}`);

    try {
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(payload),
        connectTimeout: 2000,
        readTimeout: 2000
      });

      if (response.responseCode === 200) {
        let resJson = JSON.parse(response.result as string) as Record<string, Object>;
        return resJson;
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } catch (e) {
      console.warn(`[HttpService] Request to ${path} failed. Will fallback to mock. Cause: ${e}`);
      return null;
    } finally {
      httpRequest.destroy();
    }
  }

  public async getSensorHistory(sensorType: string, timeRange: string): Promise<Record<string, Object> | null> {
    let payload = new AppApiPayload();
    let query = new ApiQueryPayload();
    query.sensor_type = sensorType;
    query.time_range = timeRange;
    payload.query = query;
    return await this.postRequest('/api/v1/sensor/history', payload);
  }

  public async getEquipmentStats(deviceType: string, timeRange: string): Promise<Record<string, Object> | null> {
    let payload = new AppApiPayload();
    let query = new ApiQueryPayload();
    query.device_type = deviceType;
    query.time_range = timeRange;
    payload.query = query;
    return await this.postRequest('/api/v1/equipment/stats', payload);
  }

  public async saveSettings(autoIrrigation: boolean, autoCooling: boolean, tempHigh: number,
    humidLow: number): Promise<boolean> {
    let payload = new AppApiPayload();
    let dataPayload = new ApiDataPayload();

    let automation = new ApiDataSettingsPayload();
    automation.auto_irrigation = autoIrrigation;
    automation.auto_cooling = autoCooling;

    let thresholds = new ApiDataSettingsPayload();
    thresholds.temp_high_alert = tempHigh;
    thresholds.humid_low_alert = humidLow;

    dataPayload.automation = automation;
    dataPayload.thresholds = thresholds;
    payload.data = dataPayload;

    let res = await this.postRequest('/api/v1/settings/save', payload);
    return res !== null;
  }
}
