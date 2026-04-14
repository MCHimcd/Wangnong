import type {
  MqttClient,
  MqttClientOptions,
  MqttConnectOptions,
  MqttMessage,
  MqttPublishOptions,
  MqttResponse,
  MqttSubscribeOptions
} from '@ohos/mqtt';
import { MqttAsync } from '@ohos/mqtt';

/**
 * Purpose: 统一管理 MQTT 连接、主题订阅、遥测缓存和控制命令发布。
 * Responsibilities: 建立单例连接、维护重连退避、缓存 60 点趋势数据、分发遥测/告警监听器，并串行排空控制命令队列。
 * Flow: Index 调用 connect() 后进入 doConnect()；消息统一在 messageArrived() 中分发；页面通过 enqueueCommand() 入队控制命令。
 * Dependencies: 依赖 @ohos/mqtt 提供客户端能力，被 Index、AlertSyncService、MonitorView 等页面与服务共享。
 * Input: Broker 地址、客户端 ID、MQTT 消息、控制命令参数。
 * Output: 连接状态回调、趋势缓存、告警/遥测监听通知和发布到 command topic 的控制消息。
 * Invariant: 遥测缓存最多保留 60 个点；控制命令应先入队再由 kickDrain() 统一发布，避免 UI 线程直接构造复杂 MQTT 对象。
 */
export class CachedTrendPoint {
  time: string = '';
  value: number = 0;

  constructor(time: string, value: number) {
    this.time = time;
    this.value = value;
  }
}

type EnvironmentData = Record<string, number | undefined>;

type EquipmentData = Record<string, boolean | undefined>;

class TelemetryData {
  environment?: EnvironmentData;
  equipment?: EquipmentData;
}

class TelemetryPayload {
  msg_type?: string;
  node_id?: string;
  timestamp?: number;
  source?: string;
  data?: TelemetryData;
}

class AlertPayload {
  msg_type?: string;
  node_id?: string;
  timestamp?: number;
  data?: Record<string, Object | string | number | boolean | null>;
}

class ControlAction {
  target_device?: string;
  command?: string;
  parameters?: Record<string, number>;
}

class ControlMessage {
  cmd_id?: string;
  timestamp?: number;
  msg_type?: string;
  source?: string;
  action?: ControlAction;
}

class PendingCommand {
  nodeId: string = '';
  targetDevice: string = '';
  action: string = '';
  paramDuration: number = 15;
  paramBrightness: number = -1;
  source: string = 'manual';
}

export class MqttClientService {
  private static instance: MqttClientService;
  private static readonly MAX_TREND_POINTS: number = 60;
  private static readonly RECONNECT_DELAY_MS: number = 3000;
  private static readonly MAX_RECONNECT_DELAY_MS: number = 30000;
  private onTelemetryDataListeners: Array<(nodeId: string, msgStr: string) => void> = [];
  private onAlertDataListeners: Array<(nodeId: string, msgStr: string) => void> = [];
  private onOfflineCallback: (() => void) | null = null;
  private offlineTimerId: number = -1;
  private connected: boolean = false;
  private client: MqttClient | null = null;
  private trendCache: Record<string, CachedTrendPoint[]> = {};
  private reconnectTimerId: number = -1;
  private reconnectDelay: number = MqttClientService.RECONNECT_DELAY_MS;
  private cachedBrokerUrl: string = '';
  private cachedClientId: string = '';
  private onStatusChangeCallback: ((status: 'connected' | 'disconnected', debugInfo?: string) => void) | null = null;
  private pendingCommands: PendingCommand[] = [];
  private drainRunning: boolean = false;
  private drainSeq: number = 0;

  private constructor() {
    this.kickDrain();
  }

  public static getInstance(): MqttClientService {
    if (!MqttClientService.instance) {
      MqttClientService.instance = new MqttClientService();
    }
    return MqttClientService.instance;
  }

  public setOnOfflineCallback(callback: () => void) {
    this.onOfflineCallback = callback;
  }

  private formatTrendTime(timestamp: number): string {
    let date = new Date(timestamp);
    let hour = date.getHours().toString().padStart(2, '0');
    let minute = date.getMinutes().toString().padStart(2, '0');
    let second = date.getSeconds().toString().padStart(2, '0');
    return `${hour}:${minute}:${second}`;
  }

  private cacheSingleMetric(nodeId: string, metric: string, value: number | undefined, timeLabel: string) {
    if (typeof value !== 'number') {
      return;
    }

    let cacheKey = `${nodeId}_${metric}`;
    let cachedPoints = this.trendCache[cacheKey] || [];
    let lastPoint = cachedPoints.length > 0 ? cachedPoints[cachedPoints.length - 1] : null;
    // Reason: 连续相同值不重复入缓存，可减少静态平台期对图表刷新和存储的噪声。
    if (lastPoint && lastPoint.value === value) {
      this.trendCache[cacheKey] = cachedPoints;
      return;
    }

    cachedPoints.push(new CachedTrendPoint(timeLabel, value));
    if (cachedPoints.length > MqttClientService.MAX_TREND_POINTS) {
      cachedPoints.shift();
    }
    this.trendCache[cacheKey] = cachedPoints;
  }

  private cacheTelemetry(nodeId: string, data?: TelemetryData, timestamp?: number) {
    if (!data || !data.environment) {
      return;
    }

    // Flow: 只缓存 environment 指标，设备开关状态仍直接交给业务层处理，不混入趋势图缓存。
    let env: EnvironmentData = data.environment;
    let timeLabel = this.formatTrendTime(timestamp || new Date().getTime());

    const keys = Object.keys(env);
    for (let i = 0; i < keys.length; i++) {
      this.cacheSingleMetric(nodeId, keys[i], env[keys[i]], timeLabel);
    }
  }

  public getCachedTrend(nodeId: string, metricKey: string): CachedTrendPoint[] {
    let cacheKey = `${nodeId}_${metricKey}`;
    let cachedPoints = this.trendCache[cacheKey] || [];
    let result: CachedTrendPoint[] = [];
    cachedPoints.forEach((point) => {
      result.push(new CachedTrendPoint(point.time, point.value));
    });
    return result;
  }

  private resetOfflineTimer() {
    if (this.offlineTimerId !== -1) {
      clearTimeout(this.offlineTimerId);
    }
    this.offlineTimerId = setTimeout(() => {
      console.warn('[MQTT] Device heartbeat timeout (30s)! Status: Offline.');
      if (this.onOfflineCallback) {
        this.onOfflineCallback();
      }
    }, 30000);
  }

  public addTelemetryListener(listener: (nodeId: string, msgStr: string) => void) {
    if (this.onTelemetryDataListeners.indexOf(listener) === -1) {
      this.onTelemetryDataListeners.push(listener);
    }
  }

  public removeTelemetryListener(listener: (nodeId: string, msgStr: string) => void) {
    const index = this.onTelemetryDataListeners.indexOf(listener);
    if (index > -1) {
      this.onTelemetryDataListeners.splice(index, 1);
    }
  }

  public addAlertListener(listener: (nodeId: string, msgStr: string) => void) {
    if (this.onAlertDataListeners.indexOf(listener) === -1) {
      this.onAlertDataListeners.push(listener);
    }
  }

  public removeAlertListener(listener: (nodeId: string, msgStr: string) => void) {
    const index = this.onAlertDataListeners.indexOf(listener);
    if (index > -1) {
      this.onAlertDataListeners.splice(index, 1);
    }
  }

  public emitLocalTelemetry(nodeId: string, msgStr: string): void {
    try {
      const payload = JSON.parse(msgStr) as TelemetryPayload;
      this.cacheTelemetry(nodeId, payload.data, payload.timestamp);
    } catch (e) {
      console.error('[MQTT] Failed to emit local telemetry', e);
      return;
    }

    this.onTelemetryDataListeners.forEach((listener: (nodeId: string, msgStr: string) => void) => {
      listener(nodeId, msgStr);
    });
  }

  public connect(brokerUrl: string, clientId: string,
    onTelemetryData: (nodeId: string, msgStr: string) => void,
    onStatusChange?: (status: 'connected' | 'disconnected', debugInfo?: string) => void) {
    this.addTelemetryListener(onTelemetryData);
    this.cachedBrokerUrl = brokerUrl;
    this.cachedClientId = clientId;
    if (onStatusChange) {
      this.onStatusChangeCallback = onStatusChange;
    }
    console.info(`[MQTT] Connecting to ${brokerUrl}`);
    if (this.onStatusChangeCallback) {
      this.onStatusChangeCallback('disconnected', 'Init connection...');
    }

    this.doConnect();
  }

  private doConnect() {
    let brokerUrl = this.cachedBrokerUrl;
    try {
      let createOpts: MqttClientOptions = {
        url: brokerUrl,
        clientId: this.cachedClientId,
        persistenceType: 1,
      };
      this.client = MqttAsync.createMqtt(createOpts);

      if (this.client) {
        let connectOpts: MqttConnectOptions = {
          MQTTVersion: 0,
          keepAliveInterval: 60
        };

        this.client.connect(connectOpts, (err, data) => {
          if (err) {
            console.error(`[MQTT] Failed to connect: ${JSON.stringify(err)}`);
            this.connected = false;
            if (this.onStatusChangeCallback) {
              this.onStatusChangeCallback('disconnected', `Connect failed: ${JSON.stringify(err)}`);
            }
            this.scheduleReconnect();
            return;
          }

          console.info(`[MQTT] Connected to ${brokerUrl}`);
          this.connected = true;
          this.reconnectDelay = MqttClientService.RECONNECT_DELAY_MS;
          if (this.onStatusChangeCallback) {
            this.onStatusChangeCallback('connected', `Success connected to ${brokerUrl}`);
          }

          if (this.client) {
            let telemetrySubOpts: MqttSubscribeOptions = { topic: '/wangnong_2026/node/+/telemetry', qos: 1 };
            let alertSubOpts: MqttSubscribeOptions = { topic: '/wangnong_2026/node/+/alert', qos: 1 };

            // Flow: 所有下游页面都从统一的 messageArrived() 分发入口拿消息，这里负责按 msg_type 切分告警与遥测。
            this.client.connectLost((err: Error, data: MqttResponse) => {
              console.warn(`[MQTT] Connection lost: ${JSON.stringify(data)}`);
              this.connected = false;
              if (this.onStatusChangeCallback) {
                this.onStatusChangeCallback('disconnected', `Connection lost`);
              }
              this.scheduleReconnect();
            });

            this.client.messageArrived((err, mqttMessage: MqttMessage) => {
              if (err) {
                return;
              }
              let payloadStr = mqttMessage.payload;
              try {
                const parsed = JSON.parse(payloadStr) as TelemetryPayload | AlertPayload;
                const msgType = parsed.msg_type || '';
                if (msgType === 'alert') {
                  const alertPayload = parsed as AlertPayload;
                  const alertNodeId = alertPayload.node_id || '';
                  this.onAlertDataListeners.forEach(listener => {
                    listener(alertNodeId, payloadStr);
                  });
                  return;
                }

                const payload = parsed as TelemetryPayload;
                if (payload.node_id) {
                  this.cacheTelemetry(payload.node_id, payload.data, payload.timestamp);
                  this.onTelemetryDataListeners.forEach(listener => {
                    listener(payload.node_id!, payloadStr);
                  });
                  this.resetOfflineTimer();
                }
              } catch (e) {
                console.error('[MQTT] Parse error', e);
                if (this.onStatusChangeCallback) {
                  this.onStatusChangeCallback('connected', `Msg arrived but parse fail: ${e}.`);
                }
              }
            });

            this.client.subscribe(telemetrySubOpts, (err, res) => {
              if (err) {
                console.error('[MQTT] Telemetry subscribe error', err);
              } else {
                console.info('[MQTT] Subscribed telemetry topic');
              }
            });

            this.client.subscribe(alertSubOpts, (err, res) => {
              if (err) {
                console.error('[MQTT] Alert subscribe error', err);
              } else {
                console.info('[MQTT] Subscribed alert topic');
              }
            });
          }
        });
      }
    } catch (e) {
      console.error(`[MQTT] Library load failed: ${e}`);
      this.connected = false;
      if (this.onStatusChangeCallback) {
        this.onStatusChangeCallback('disconnected', `Catch error: ${e.message || e}`);
      }
      this.scheduleReconnect();
    }
  }

  private scheduleReconnect() {
    if (this.reconnectTimerId !== -1) {
      clearTimeout(this.reconnectTimerId);
    }
    console.info(`[MQTT] Scheduling reconnect in ${this.reconnectDelay}ms`);
    this.reconnectTimerId = setTimeout(() => {
      this.reconnectTimerId = -1;
      console.info('[MQTT] Attempting reconnect...');
      this.doConnect();
    }, this.reconnectDelay);
    // Reason: 使用指数退避避免在 Broker 不可用时持续高频重试；成功连接后会把延迟重置回初始值。
    this.reconnectDelay = Math.min(this.reconnectDelay * 2, MqttClientService.MAX_RECONNECT_DELAY_MS);
  }

  public isConnected(): boolean {
    return this.connected;
  }

  public getCommandQueueLength(): number {
    return this.pendingCommands.length;
  }

  public clearCommandQueue(): void {
    this.pendingCommands.splice(0, this.pendingCommands.length);
  }

  /**
   * UI 调用入口：只存原始参数（纯字符串/数字），不创建任何 @ohos/mqtt 对象
   */
  public enqueueCommand(nodeId: string, targetDevice: string, action: string,
    param?: Record<string, number>, source: string = 'manual') {
    let cmd = new PendingCommand();
    cmd.nodeId = nodeId;
    cmd.targetDevice = targetDevice;
    cmd.action = action;
    cmd.source = source;
    if (param) {
      let dur = param['duration_seconds'];
      if (dur !== undefined) {
        cmd.paramDuration = dur;
      }
      let br = param['brightness'];
      if (br !== undefined) {
        cmd.paramBrightness = br;
      }
    }
    // Boundary: UI 层只提交原始控制意图，真正的 MQTT payload 组装延后到 drain tick 中执行。
    this.pendingCommands.push(cmd);
    console.info(`[MQTT] Command enqueued: node=${nodeId} dev=${targetDevice} act=${action} source=${source} queueLen=${this.pendingCommands.length}`);
  }

  /**
   * 递归 setTimeout 驱动。
   * 关键：MqttPublishOptions / ControlMessage / JSON 全部在此 timer 回调内构造，
   * 完全复刻 debug loop 成功时的执行上下文。
   */
  private kickDrain() {
    if (this.drainRunning) {
      return;
    }
    this.drainRunning = true;
    const tick = () => {
      this.drainSeq++;
      if (this.pendingCommands.length > 0 && this.client && this.connected) {
        let batch = this.pendingCommands.splice(0, this.pendingCommands.length);
        let client = this.client;
        console.info(`[MQTT] drain tick #${this.drainSeq}: publishing ${batch.length} command(s)`);
        for (let i = 0; i < batch.length; i++) {
          let cmd = batch[i];
          // Reason: 在 timer 回调里现构造发布对象，可复用已验证的异步上下文，降低直接从 UI 事件中 publish 的不稳定性。
          let ctrlAction = new ControlAction();
          ctrlAction.target_device = cmd.targetDevice;
          ctrlAction.command = cmd.action;
          let paramMap: Record<string, number> = {};
          paramMap['duration_seconds'] = cmd.paramDuration;
          if (cmd.paramBrightness >= 0) {
            paramMap['brightness'] = cmd.paramBrightness;
          }
          ctrlAction.parameters = paramMap;

          let ctrlMsg = new ControlMessage();
          ctrlMsg.cmd_id = "app_" + new Date().getTime().toString();
          ctrlMsg.timestamp = new Date().getTime();
          ctrlMsg.msg_type = "control";
          ctrlMsg.source = cmd.source;
          ctrlMsg.action = ctrlAction;

          let payloadStr = JSON.stringify(ctrlMsg);
          let topic = `/wangnong_2026/node/${cmd.nodeId}/command`;

          let pubOpts: MqttPublishOptions = {
            topic: topic,
            payload: payloadStr,
            qos: 1,
            retained: false
          };
          try {
            let promise: Promise<MqttResponse> = client.publish(pubOpts);
            promise.then((data: MqttResponse) => {
              console.info(`[MQTT] <<< drain Publish OK topic=${topic}`);
            }).catch((err: Error) => {
              console.error(`[MQTT] <<< drain Publish REJECTED topic=${topic} err=${JSON.stringify(err)}`);
            });
            console.info(`[MQTT] >>> drain publish fired: topic=${topic}`);
          } catch (e) {
            console.error(`[MQTT] >>> drain publish THREW: topic=${topic} err=${JSON.stringify(e)}`);
          }
        }
      }
      let delay = this.pendingCommands.length > 0 ? 200 : 2000;
      setTimeout(tick, delay);
    };
    setTimeout(tick, 500);
  }

  public publishCommand(nodeId: string, targetDevice: string, action: string, param?: Record<string, number>): string {
    if (!this.client) {
      console.warn(`[MQTT] publishCommand blocked: client is null`);
      return 'MQTT客户端未初始化';
    }
    if (!this.connected) {
      console.warn(`[MQTT] publishCommand blocked: connected=false`);
      return 'MQTT未连接(connected=false)';
    }

    let ctrlAction = new ControlAction();
    ctrlAction.target_device = targetDevice;
    ctrlAction.command = action;
    ctrlAction.parameters = param || { "duration_seconds": 15 };

    let ctrlMsg = new ControlMessage();
    ctrlMsg.cmd_id = "app_" + new Date().getTime();
    ctrlMsg.timestamp = new Date().getTime();
    ctrlMsg.msg_type = "control";
    ctrlMsg.source = "manual";
    ctrlMsg.action = ctrlAction;

    let payloadStr = JSON.stringify(ctrlMsg);

    let topic = `/wangnong_2026/node/${nodeId}/command`;
    console.info(`[MQTT] >>> Publish START topic=${topic} payload=${payloadStr}`);
    let pubOpts: MqttPublishOptions = {
      topic: topic,
      payload: payloadStr,
      qos: 1,
      retained: false
    };
    let client = this.client;
    try {
      let promise: Promise<MqttResponse> = client.publish(pubOpts);
      promise.then((data: MqttResponse) => {
        console.info(`[MQTT] <<< Publish OK topic=${topic} response=${JSON.stringify(data)}`);
      }).catch((err: Error) => {
        console.error(`[MQTT] <<< Publish REJECTED topic=${topic} error=${JSON.stringify(err)}`);
      });
      console.info(`[MQTT] >>> Publish CALLED (promise qos1) topic=${topic}`);
    } catch (e) {
      console.error(`[MQTT] >>> Publish THREW topic=${topic} error=${JSON.stringify(e)}`);
      return `publish异常: ${e}`;
    }
    return '';
  }

  public disconnect() {
    this.connected = false;
    this.drainRunning = false;
    if (this.reconnectTimerId !== -1) {
      clearTimeout(this.reconnectTimerId);
      this.reconnectTimerId = -1;
    }
    if (this.client && this.client.disconnect) {
      try {
        this.client.disconnect();
      } catch (e) {
        console.error('[MQTT] Disconnect error', e);
      }
    }
    console.info('[MQTT] Disconnected');
  }

}
