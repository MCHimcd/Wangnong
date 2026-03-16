import http from '@ohos.net.http';
import { LoginResponse, UserProfile, BaseResponse } from '../models/UserData';
import { ArticleData } from '../models/ArticleData';
import { LiveStreamInfo, PlaybackItem, KeyframeImageItem } from '../models/VideoMonitorData';

const BASE_URL = 'http://192.168.1.100:8080';
const APP_ID = 'WN_APP_001';

export class LoginRequest {
  username: string = "";
  password: string = "";
}

export class RegisterRequest {
  phone: string = "";
  verificationCode: string = "";
  password: string = "";
}

export class ForgotPasswordRequest {
  phone: string = "";
  verificationCode: string = "";
  newPassword: string = "";
}

export class ChangePasswordRequest {
  oldPassword: string = "";
  newPassword: string = "";
}

export class LogoutRequest {
}

export class ApiQueryPayload {
  sensor_type?: string;
  device_type?: string;
  time_range?: string;
  scene?: string;
  page?: number;
  size?: number;
  sort_by?: string;
  order?: string;
  filter_type?: string;
  filter_status?: string;
}

export class ApiDataPayload {
  alert_id?: string;
  action?: string;
  notes?: string;
}

export class AppApiPayload {
  app_id: string = APP_ID;
  device_id: string = "";
  timestamp: number = 0;
  query?: ApiQueryPayload;
  data?: ApiDataPayload;
}

export interface DeviceSummary {
  total_value: number;
  unit: string;
}

export interface DeviceDataPoint {
  timeLabel: string;
  value: number;
}

export interface EquipmentStatsData {
  summary: DeviceSummary;
  points: DeviceDataPoint[];
}

export interface SensorHistoryPoint {
  timeLabel: string;
  value: number;
}

export interface SensorHistorySummary {
  max: number;
  min: number;
  avg: number;
}

export interface SensorHistoryData {
  metric: string;
  summary: SensorHistorySummary;
  points: SensorHistoryPoint[];
}

export interface AlertListItem {
  alert_id: string;
  type: string;
  type_name: string;
  level: string;
  timestamp: number;
  message: string;
  source: string;
  source_name: string;
  is_handled: boolean;
  handle_time: number | null;
}

export interface AlertListData {
  total: number;
  unhandled_count?: number;
  handled_recent_count?: number;
  items: AlertListItem[];
}

export interface DeviceDetailStateData {
  waterValveOn?: boolean;
  waterPumpOn?: boolean;
  ledOn?: boolean;
  fanOn?: boolean;
  extensionOn?: boolean;
  smartMode?: boolean;
}

export interface DeviceDetailData {
  id: string;
  name: string;
  status: string;
  sensorData?: Record<string, number>;
  deviceState?: DeviceDetailStateData;
}

export interface DeviceListItem {
  id: string;
  name: string;
  status: string;
}

export class HttpService {
  private static instance: HttpService;
  private currentDeviceId: string = "A03_Node_01";
  private token: string = "";

  private constructor() {}

  public static getInstance(): HttpService {
    if (!HttpService.instance) {
      HttpService.instance = new HttpService();
    }
    return HttpService.instance;
  }

  public setToken(token: string) {
    this.token = token;
  }

  public setDeviceId(id: string) {
    this.currentDeviceId = id;
  }

  private async request<T>(path: string, method: http.RequestMethod, extraData?: Object): Promise<T | null> {
    let httpRequest = http.createHttp();
    let url = `${BASE_URL}${path}`;

    let header: Record<string, string> = { 
      'Content-Type': 'application/json' 
    };
    
    if (this.token) {
      header['Authorization'] = `Bearer ${this.token}`;
    }

    console.info(`[HttpService] ${method} ${url}`);
    
    try {
      let options: http.HttpRequestOptions = {
        method: method,
        header: header,
        connectTimeout: 2000,
        readTimeout: 2000
      };
      
      if (extraData) {
        options.extraData = JSON.stringify(extraData);
      }
      
      let response = await httpRequest.request(url, options);

      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } catch (e) {
      console.warn(`[HttpService] Request to ${path} failed. Cause: ${e}`);
      return null;
    } finally {
      httpRequest.destroy();
    }
  }

  public async login(username: string, password: string): Promise<LoginResponse | null> {
    let req = new LoginRequest();
    req.username = username;
    req.password = password;

    let res = await this.request<BaseResponse<LoginResponse>>(
      '/api/v1/auth/login', 
      http.RequestMethod.POST, 
      req
    );
    return res ? res.data : null;
  }

  public async register(phone: string, verificationCode: string, password: string): Promise<boolean> {
    let req = new RegisterRequest();
    req.phone = phone;
    req.verificationCode = verificationCode;
    req.password = password;

    let res = await this.request<BaseResponse<Object>>(
      '/api/v1/auth/register',
      http.RequestMethod.POST,
      req
    );
    return res !== null;
  }

  public async forgotPassword(phone: string, verificationCode: string, newPassword: string): Promise<boolean> {
    let req = new ForgotPasswordRequest();
    req.phone = phone;
    req.verificationCode = verificationCode;
    req.newPassword = newPassword;

    let res = await this.request<BaseResponse<Object>>(
      '/api/v1/auth/forgot-password',
      http.RequestMethod.POST,
      req
    );
    return res !== null;
  }

  public async changePassword(oldPassword: string, newPassword: string): Promise<boolean> {
    let payload = new ChangePasswordRequest();
    payload.oldPassword = oldPassword;
    payload.newPassword = newPassword;

    let res = await this.request<BaseResponse<Object>>(
      '/api/v1/auth/password',
      http.RequestMethod.PUT,
      payload
    );
    return res !== null;
  }

  public async logout(): Promise<boolean> {
    let payload = new LogoutRequest();
    let res = await this.request<BaseResponse<Object>>(
      '/api/v1/auth/logout',
      http.RequestMethod.POST,
      payload
    );
    if (res !== null) {
      this.token = '';
      return true;
    }
    return false;
  }

  public async getUserProfile(): Promise<UserProfile | null> {
    let res = await this.request<BaseResponse<UserProfile>>(
      '/api/v1/auth/profile',
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async updateUserProfile(profile: UserProfile): Promise<boolean> {
    let res = await this.request<BaseResponse<Object>>(
      '/api/v1/auth/profile',
      http.RequestMethod.PUT,
      profile
    );
    return res !== null;
  }

  public async getSensorHistory(deviceId: string, range: string, metric: string): Promise<SensorHistoryData | null> {
    let res = await this.request<BaseResponse<SensorHistoryData>>(
      `/api/v1/sensors/${deviceId}/history?range=${range}&metric=${metric}`,
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async getDeviceDetail(deviceId: string): Promise<DeviceDetailData | null> {
    let res = await this.request<BaseResponse<DeviceDetailData>>(
      `/api/v1/devices/${deviceId}`,
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async getDevices(): Promise<DeviceListItem[] | null> {
    let res = await this.request<BaseResponse<DeviceListItem[]>>(
      '/api/v1/devices',
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async getEquipmentStats(deviceType: string, timeRange: string): Promise<BaseResponse<EquipmentStatsData> | null> {
    let payload = new AppApiPayload();
    let query = new ApiQueryPayload();
    query.device_type = deviceType;
    query.time_range = timeRange;
    payload.query = query;
    return await this.request<BaseResponse<EquipmentStatsData>>('/api/v1/equipment/stats', http.RequestMethod.POST, payload);
  }

  public async getAlerts(scene: string = '', page: number = 1, size: number = 20, sortBy: string = 'timestamp',
    order: string = 'desc', filterType: string = '', filterStatus: string = ''): Promise<BaseResponse<AlertListData> | null> {
    let payload = new AppApiPayload();
    let query = new ApiQueryPayload();
    query.scene = scene;
    query.page = page;
    query.size = size;
    query.sort_by = sortBy;
    query.order = order;
    query.filter_type = filterType;
    query.filter_status = filterStatus;
    payload.query = query;

    return await this.request<BaseResponse<AlertListData>>('/api/v1/alerts/list', http.RequestMethod.POST, payload);
  }

  public async handleAlert(alertId: string, action: string, notes?: string): Promise<boolean> {
    let payload = new AppApiPayload();
    let dataPayload = new ApiDataPayload();
    dataPayload.alert_id = alertId;
    dataPayload.action = action;
    if (notes) {
      dataPayload.notes = notes;
    }
    payload.data = dataPayload;
    let res = await this.request<BaseResponse<Object>>('/api/v1/alerts/handle', http.RequestMethod.POST, payload);
    return res !== null;
  }

  // ==== 知识库文章 ====
  public async getArticles(page: number = 1, size: number = 10): Promise<BaseResponse<Record<string, Object>> | null> {
    return await this.request<BaseResponse<Record<string, Object>>>(`/api/v1/articles?page=${page}&size=${size}`, http.RequestMethod.GET);
  }

  public async getArticleDetail(id: string): Promise<BaseResponse<ArticleData> | null> {
    return await this.request<BaseResponse<ArticleData>>(`/api/v1/articles/${id}`, http.RequestMethod.GET);
  }

  // ==== 视频流及抓拍 ====
  public async getCameraLive(deviceId: string): Promise<BaseResponse<LiveStreamInfo> | null> {
    return await this.request<BaseResponse<LiveStreamInfo>>(`/api/v1/cameras/${deviceId}/live`, http.RequestMethod.GET);
  }

  public async getCameraPlayback(deviceId: string, date: string): Promise<BaseResponse<PlaybackItem[]> | null> {
    return await this.request<BaseResponse<PlaybackItem[]>>(`/api/v1/cameras/${deviceId}/playback?date=${date}`, http.RequestMethod.GET);
  }

  public async getCameraKeyframes(deviceId: string, date: string): Promise<BaseResponse<KeyframeImageItem[]> | null> {
    return await this.request<BaseResponse<KeyframeImageItem[]>>(`/api/v1/cameras/${deviceId}/keyframes?date=${date}`, http.RequestMethod.GET);
  }

  // ==== 虫害检测 ====
  public async analyzePest(imageUri: string): Promise<BaseResponse<Record<string, string>> | null> {
    let payload = new AppApiPayload();
    let dataPayload = new ApiDataPayload();
    dataPayload.notes = `image_uri: ${imageUri}`;
    payload.data = dataPayload;
    return await this.request<BaseResponse<Record<string, string>>>('/api/v1/pest-detection/analyze', http.RequestMethod.POST, payload);
  }
}


