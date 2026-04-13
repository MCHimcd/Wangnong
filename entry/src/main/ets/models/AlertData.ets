/**
 * Purpose: 描述前端统一使用的告警记录结构。
 * Responsibilities: 承载告警类型、级别、时间、来源和处理状态，供列表、详情和同步服务共享。
 * Flow: HttpService 反序列化后由 AlertSyncService、AlertView、AlertDetailPage 消费。
 * Dependencies: 被页面和服务层直接引用。
 * Input: 来自 HTTP / MQTT 的告警字段。
 * Output: 可被 UI 直接展示和排序的告警对象。
 */
export class AlertData {
  alert_id: string = '';
  type: string = '';
  type_name: string = '';
  level: string = '';
  timestamp: number = 0;
  message: string = '';
  source: string = 'environment';
  source_name: string = '环境监测';
  is_handled: boolean = false;
  handle_time: number | null = null;
}
