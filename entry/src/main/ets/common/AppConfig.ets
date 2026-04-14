/**
 * Purpose: 统一声明应用运行时依赖的环境常量，避免各页面和服务散落硬编码地址。
 * Responsibilities: 提供 HTTP 基地址、MQTT Broker 地址、客户端 ID 前缀和应用标识。
 * Flow: 启动后由 HttpService、MqttClientService、视频与页面模块读取这些常量拼接请求和连接参数。
 * Dependencies: 被 services、pages、views 层直接导入使用。
 * Input: 无运行时输入，环境切换通过修改常量值完成。
 * Output: 导出只读配置常量。
 * Boundary: 该文件仅承载静态配置，不负责运行时切换或密钥管理。
 */
export class AppConfig {
  /** HTTP 后端基地址 */
  // static readonly BASE_URL: string = 'http://47.109.27.231:8080';
  static readonly BASE_URL: string = 'http://192.168.1.101:8080';

  /** MQTT Broker 连接地址 */
  // static readonly MQTT_BROKER_URL: string = 'tcp://broker.emqx.io:1883';
  static readonly MQTT_BROKER_URL: string = 'tcp://8.156.84.57:1883';

  /** MQTT 客户端 ID 前缀（实际 ID = 前缀 + 时间戳） */
  static readonly MQTT_CLIENT_PREFIX: string = 'app_client_';

  /** 应用标识 */
  static readonly APP_ID: string = 'WN_APP_001';
}
