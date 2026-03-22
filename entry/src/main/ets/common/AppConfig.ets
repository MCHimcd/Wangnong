/**
 * 应用可变配置项 —— 在此统一管理服务器地址、MQTT 参数等环境相关常量。
 */
export class AppConfig {
  /** HTTP 后端基地址 */
  static readonly BASE_URL: string = 'http://192.168.1.101:8080';

  /** MQTT Broker 连接地址 */
  static readonly MQTT_BROKER_URL: string = 'tcp://broker.emqx.io:1883';

  /** MQTT 客户端 ID 前缀（实际 ID = 前缀 + 时间戳） */
  static readonly MQTT_CLIENT_PREFIX: string = 'app_client_';

  /** 应用标识 */
  static readonly APP_ID: string = 'WN_APP_001';
}
