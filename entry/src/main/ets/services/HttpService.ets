import http from '@ohos.net.http';
import { LoginResponse, UserProfile, BaseResponse } from '../models/UserData';
import { SensorMetaItem } from '../models/SensorMeta';
import { EquipmentMetaItem } from '../models/EquipmentMeta';
import { LiveStreamInfo, PlaybackItem, KeyframeImageItem } from '../models/VideoMonitorData';
import { AppConfig } from '../common/AppConfig';

const BASE_URL = AppConfig.BASE_URL;
const APP_ID = AppConfig.APP_ID;

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

export class SendVerificationCodeRequest {
  phone: string = "";
}

export class ChangePasswordRequest {
  oldPassword: string = "";
  newPassword: string = "";
}

export class LogoutRequest {
}

export class HealthStatusData {
  available: boolean = false;
  mqttConnected: boolean = false;
  application: string = '';
  mode: string = '';
  dataSimulated: boolean = false;
  time: string = '';
}

export class TraceabilityScanRequest {
  code: string = "";
}

export class ApiQueryPayload {
  sensor_type?: string;
  equipment_type?: string;
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
  node_id: string = "";
  timestamp: number = 0;
  query?: ApiQueryPayload;
  data?: ApiDataPayload;
}

export interface EquipmentSummary {
  total_value: number;
  unit: string;
}

export interface EquipmentDataPoint {
  timeLabel: string;
  value: number;
}

export interface EquipmentStatsData {
  summary: EquipmentSummary;
  points: EquipmentDataPoint[];
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

export type NodeDetailStateData = Record<string, boolean | undefined>;

export interface NodeDetailData {
  id: string;
  name: string;
  status: string;
  sensorData?: Record<string, number>;
  nodeState?: NodeDetailStateData;
}

export interface NodeListItem {
  id: string;
  name: string;
  status: string;
}

export interface AdminUserInfo {
  id: number;
  userName: string;
  phone: string;
  role: string;
}

export class AdminCreateNodeRequest {
  nodeId: string = '';
  nodeName: string = '';
}

export class AdminUpdateNodeRequest {
  nodeName: string = '';
}

export class AdminUpdateRoleRequest {
  role: string = '';
}

export class SetUserNodesRequest {
  nodeIds: string[] = [];
}

export interface ScheduledTaskItem {
  id: number;
  nodeId: string;
  equipmentKey: string;
  action: string;
  taskName: string;
  hour: number;
  minute: number;
  repeatDays: string;
  enabled: boolean;
  createdAt: number;
}

export class CreateTaskRequest {
  nodeId: string = '';
  equipmentKey: string = '';
  action: string = '';
  taskName: string = '';
  hour: number = 0;
  minute: number = 0;
  repeatDays: string = '';
}

export class UpdateTaskRequest {
  nodeId: string = '';
  equipmentKey: string = '';
  action: string = '';
  taskName: string = '';
  hour: number = 0;
  minute: number = 0;
  repeatDays: string = '';
}

export class ThresholdUpdateItem {
  sensorKey: string = '';
  warningMin: number | null = null;
  warningMax: number | null = null;
}

export interface OperationLogItem {
  id: number;
  userId: number | null;
  userName: string | null;
  operationType: string;
  targetType: string | null;
  targetId: string | null;
  detail: string | null;
  createdAt: string | null;
}

export interface OperationLogPage {
  total: number;
  items: OperationLogItem[];
}

export class HttpService {
  private static instance: HttpService;
  private currentNodeId: string = "A03_Node_01";
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

  public setNodeId(id: string) {
    this.currentNodeId = id;
  }

  private async request<T>(path: string, method: http.RequestMethod, extraData?: Object,
    connectTimeoutMs: number = 2000, readTimeoutMs: number = 2000): Promise<T | null> {
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
        connectTimeout: connectTimeoutMs,
        readTimeout: readTimeoutMs
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

  public async sendVerificationCode(phone: string): Promise<boolean> {
    let req = new SendVerificationCodeRequest();
    req.phone = phone;

    let res = await this.request<BaseResponse<Object>>(
      '/api/v1/auth/send-verification-code',
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

  public async checkServerHealth(): Promise<boolean> {
    let res = await this.request<BaseResponse<HealthStatusData>>(
      '/api/v1/health',
      http.RequestMethod.GET,
      undefined,
      1000,
      1000
    );

    if (!res || res.code !== 200 || !res.data) {
      return false;
    }
    return res.data.available === true;
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

  public async useFixedAvatar(): Promise<UserProfile | null> {
    let res = await this.request<BaseResponse<UserProfile>>(
      '/api/v1/auth/avatar/use-fixed',
      http.RequestMethod.POST
    );
    return res ? res.data : null;
  }

  public async uploadTraceCode(traceCode: string): Promise<string | null> {
    let payload = new TraceabilityScanRequest();
    payload.code = traceCode;
    let res = await this.request<BaseResponse<string>>(
      '/api/v1/traceability/scan',
      http.RequestMethod.POST,
      payload
    );
    return res ? res.data : null;
  }

  public async getSensorHistory(nodeId: string, range: string, metric: string): Promise<SensorHistoryData | null> {
    let res = await this.request<BaseResponse<SensorHistoryData>>(
      `/api/v1/sensors/${nodeId}/history?range=${range}&metric=${metric}`,
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async getNodeDetail(nodeId: string): Promise<NodeDetailData | null> {
    let res = await this.request<BaseResponse<NodeDetailData>>(
      `/api/v1/nodes/${nodeId}`,
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async getNodes(): Promise<NodeListItem[] | null> {
    let res = await this.request<BaseResponse<NodeListItem[]>>(
      '/api/v1/nodes',
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async getEquipmentStats(equipmentType: string, timeRange: string): Promise<BaseResponse<EquipmentStatsData> | null> {
    let payload = new AppApiPayload();
    let query = new ApiQueryPayload();
    query.equipment_type = equipmentType;
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

  // ==== 传感器 / 设备元数据 ====
  public async getSensorMeta(nodeId: string): Promise<SensorMetaItem[] | null> {
    let res = await this.request<BaseResponse<SensorMetaItem[]>>(
      `/api/v1/nodes/${nodeId}/sensor-meta`,
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async getEquipmentMeta(nodeId: string): Promise<EquipmentMetaItem[] | null> {
    let res = await this.request<BaseResponse<EquipmentMetaItem[]>>(
      `/api/v1/nodes/${nodeId}/equipment-meta`,
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  // ==== 农业知识问答 ====
  public async sendAgriQA(message: string, imageUri?: string): Promise<string | null> {
    let body: Record<string, string> = { "message": message };
    if (imageUri) {
      body['image_uri'] = imageUri;
    }
    let res = await this.request<BaseResponse<Record<string, string>>>(
      '/api/v1/agri-qa/chat',
      http.RequestMethod.POST,
      body,
      5000,   // connectTimeout: 5s
      60000   // readTimeout: 60s (AI responses can be slow)
    );
    if (res && res.data) {
      return (res.data as Record<string, string>)['reply'] ?? null;
    }
    return null;
  }

  // ==== 视频流及抓拍 ====
  public async getCameraLive(nodeId: string): Promise<BaseResponse<LiveStreamInfo> | null> {
    return await this.request<BaseResponse<LiveStreamInfo>>(`/api/v1/cameras/${nodeId}/live`, http.RequestMethod.GET);
  }

  public async getCameraPlayback(nodeId: string, date: string): Promise<BaseResponse<PlaybackItem[]> | null> {
    return await this.request<BaseResponse<PlaybackItem[]>>(`/api/v1/cameras/${nodeId}/playback?date=${date}`, http.RequestMethod.GET);
  }

  public async getCameraKeyframes(nodeId: string, date: string): Promise<BaseResponse<KeyframeImageItem[]> | null> {
    return await this.request<BaseResponse<KeyframeImageItem[]>>(`/api/v1/cameras/${nodeId}/keyframes?date=${date}`, http.RequestMethod.GET);
  }

  // ==== 管理员 API ====
  public async adminCreateNode(nodeId: string, nodeName: string): Promise<boolean> {
    let body = new AdminCreateNodeRequest();
    body.nodeId = nodeId;
    body.nodeName = nodeName;
    let res = await this.request<BaseResponse<Object>>(
      '/api/v1/admin/nodes',
      http.RequestMethod.POST,
      body
    );
    return res !== null && res.code === 200;
  }

  public async adminUpdateNode(nodeId: string, nodeName: string): Promise<boolean> {
    let body = new AdminUpdateNodeRequest();
    body.nodeName = nodeName;
    let res = await this.request<BaseResponse<Object>>(
      `/api/v1/admin/nodes/${nodeId}`,
      http.RequestMethod.PUT,
      body
    );
    return res !== null && res.code === 200;
  }

  public async adminDeleteNode(nodeId: string): Promise<boolean> {
    let res = await this.request<BaseResponse<Object>>(
      `/api/v1/admin/nodes/${nodeId}`,
      'DELETE' as http.RequestMethod
    );
    return res !== null && res.code === 200;
  }

  public async adminListUsers(): Promise<AdminUserInfo[] | null> {
    let res = await this.request<BaseResponse<AdminUserInfo[]>>(
      '/api/v1/admin/users',
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async adminUpdateUserRole(userId: number, role: string): Promise<boolean> {
    let body = new AdminUpdateRoleRequest();
    body.role = role;
    let res = await this.request<BaseResponse<Object>>(
      `/api/v1/admin/users/${userId}/role`,
      http.RequestMethod.PUT,
      body
    );
    return res !== null && res.code === 200;
  }

  // ==== 用户-节点授权管理 ====
  public async adminGetUserNodes(userId: number): Promise<string[] | null> {
    let res = await this.request<BaseResponse<string[]>>(
      `/api/v1/admin/users/${userId}/nodes`,
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async adminSetUserNodes(userId: number, nodeIds: string[]): Promise<boolean> {
    let body = new SetUserNodesRequest();
    body.nodeIds = nodeIds;
    let res = await this.request<BaseResponse<Object>>(
      `/api/v1/admin/users/${userId}/nodes`,
      http.RequestMethod.PUT,
      body
    );
    return res !== null && res.code === 200;
  }

  // ==== 定时任务 ====
  public async getScheduledTasks(): Promise<ScheduledTaskItem[] | null> {
    let res = await this.request<BaseResponse<ScheduledTaskItem[]>>(
      '/api/v1/tasks',
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

  public async createScheduledTask(req: CreateTaskRequest): Promise<ScheduledTaskItem | null> {
    let res = await this.request<BaseResponse<ScheduledTaskItem>>(
      '/api/v1/tasks',
      http.RequestMethod.POST,
      req
    );
    return res ? res.data : null;
  }

  public async updateScheduledTask(taskId: number, req: UpdateTaskRequest): Promise<ScheduledTaskItem | null> {
    let res = await this.request<BaseResponse<ScheduledTaskItem>>(
      `/api/v1/tasks/${taskId}`,
      http.RequestMethod.PUT,
      req
    );
    return res ? res.data : null;
  }

  public async deleteScheduledTask(taskId: number): Promise<boolean> {
    let res = await this.request<BaseResponse<Object>>(
      `/api/v1/tasks/${taskId}`,
      'DELETE' as http.RequestMethod
    );
    return res !== null;
  }

  public async toggleScheduledTask(taskId: number): Promise<boolean> {
    let res = await this.request<BaseResponse<Object>>(
      `/api/v1/tasks/${taskId}/toggle`,
      http.RequestMethod.PUT
    );
    return res !== null;
  }

  // ==== 传感器阈值更新 ====
  public async updateSensorThresholds(nodeId: string, thresholds: ThresholdUpdateItem[]): Promise<boolean> {
    let res = await this.request<BaseResponse<Object>>(
      `/api/v1/nodes/${nodeId}/sensor-thresholds`,
      http.RequestMethod.PUT,
      thresholds
    );
    return res !== null;
  }

  // ==== 操作日志 ====
  public async getOperationLogs(page: number = 1, size: number = 20, type?: string): Promise<OperationLogPage | null> {
    let url = `/api/v1/admin/logs?page=${page}&size=${size}`;
    if (type) {
      url += `&type=${type}`;
    }
    let res = await this.request<BaseResponse<OperationLogPage>>(
      url,
      http.RequestMethod.GET
    );
    return res ? res.data : null;
  }

}

