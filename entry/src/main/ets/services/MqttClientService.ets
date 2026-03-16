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

export class CachedTrendPoint {
  time: string = '';
  value: number = 0;

  constructor(time: string, value: number) {
    this.time = time;
    this.value = value;
  }
}

class EnvironmentData {
  temperature?: number;
  humidity?: number;
  light?: number;
  co2?: number;
  soilTemp?: number;
  soilHumidity?: number;
  soilPh?: number;
}

class EquipmentData {
  water_pump?: boolean;
  led_light?: boolean;
  fan?: boolean;
  camera?: boolean;
}

class TelemetryData {
  environment?: EnvironmentData;
  equipment?: EquipmentData;
}

class TelemetryPayload {
  msg_type?: string;
  device_id?: string;
  timestamp?: number;
  data?: TelemetryData;
}

class AlertPayload {
  msg_type?: string;
  device_id?: string;
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
  action?: ControlAction;
}

export class MqttClientService {
  private static instance: MqttClientService;
  private static readonly MAX_TREND_POINTS: number = 60;
  private onTelemetryDataListeners: Array<(deviceId: string, msgStr: string) => void> = [];
  private onAlertDataListeners: Array<(deviceId: string, msgStr: string) => void> = [];
  private onOfflineCallback: (() => void) | null = null;
  private offlineTimerId: number = -1;
  private connected: boolean = false;
  private client: MqttClient | null = null;
  private trendCache: Record<string, CachedTrendPoint[]> = {};

  private constructor() {
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

  private cacheSingleMetric(deviceId: string, metric: string, value: number | undefined, timeLabel: string) {
    if (typeof value !== 'number') {
      return;
    }

    let cacheKey = `${deviceId}_${metric}`;
    let cachedPoints = this.trendCache[cacheKey] || [];
    let lastPoint = cachedPoints.length > 0 ? cachedPoints[cachedPoints.length - 1] : null;
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

  private cacheTelemetry(deviceId: string, data?: TelemetryData, timestamp?: number) {
    if (!data || !data.environment) {
      return;
    }

    let env = data.environment;
    let timeLabel = this.formatTrendTime(timestamp || new Date().getTime());

    this.cacheSingleMetric(deviceId, 'temperature', env.temperature, timeLabel);
    this.cacheSingleMetric(deviceId, 'humidity', env.humidity, timeLabel);
    this.cacheSingleMetric(deviceId, 'light', env.light, timeLabel);
    this.cacheSingleMetric(deviceId, 'co2', env.co2, timeLabel);
    this.cacheSingleMetric(deviceId, 'soilTemp', env.soilTemp, timeLabel);
    this.cacheSingleMetric(deviceId, 'soilHumidity', env.soilHumidity, timeLabel);
    this.cacheSingleMetric(deviceId, 'soilPh', env.soilPh, timeLabel);
  }

  public getCachedTrend(deviceId: string, metricKey: string): CachedTrendPoint[] {
    let cacheKey = `${deviceId}_${metricKey}`;
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
      console.warn('[MQTT] Device heartbeat timeout (10s)! Status: Offline.');
      if (this.onOfflineCallback) {
        this.onOfflineCallback();
      }
    }, 10000);
  }

  public addTelemetryListener(listener: (deviceId: string, msgStr: string) => void) {
    if (this.onTelemetryDataListeners.indexOf(listener) === -1) {
      this.onTelemetryDataListeners.push(listener);
    }
  }

  public removeTelemetryListener(listener: (deviceId: string, msgStr: string) => void) {
    const index = this.onTelemetryDataListeners.indexOf(listener);
    if (index > -1) {
      this.onTelemetryDataListeners.splice(index, 1);
    }
  }

  public addAlertListener(listener: (deviceId: string, msgStr: string) => void) {
    if (this.onAlertDataListeners.indexOf(listener) === -1) {
      this.onAlertDataListeners.push(listener);
    }
  }

  public removeAlertListener(listener: (deviceId: string, msgStr: string) => void) {
    const index = this.onAlertDataListeners.indexOf(listener);
    if (index > -1) {
      this.onAlertDataListeners.splice(index, 1);
    }
  }

  public connect(brokerUrl: string, clientId: string,
    onTelemetryData: (deviceId: string, msgStr: string) => void,
    onStatusChange?: (status: 'connected' | 'disconnected', debugInfo?: string) => void) {
    this.addTelemetryListener(onTelemetryData);
    console.info(`[MQTT] Connecting to ${brokerUrl}`);
    if (onStatusChange) {
      onStatusChange('disconnected', 'Init connection...');
    }

    try {
      let createOpts: MqttClientOptions = {
        url: brokerUrl,
        clientId: clientId,
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
            if (onStatusChange) {
              onStatusChange('disconnected', `Connect failed: ${JSON.stringify(err)}`);
            }
            return;
          }

          console.info(`[MQTT] Connected to ${brokerUrl}`);
          this.connected = true;
          if (onStatusChange) {
            onStatusChange('connected', `Success connected to ${brokerUrl}`);
          }

          if (this.client) {
            let telemetrySubOpts: MqttSubscribeOptions = { topic: '/wangnong_2026/device/+/telemetry', qos: 1 };
            let alertSubOpts: MqttSubscribeOptions = { topic: '/wangnong_2026/device/+/alert', qos: 1 };

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
                  const alertDeviceId = alertPayload.device_id || '';
                  this.onAlertDataListeners.forEach(listener => {
                    listener(alertDeviceId, payloadStr);
                  });
                  return;
                }

                const payload = parsed as TelemetryPayload;
                if (payload.device_id) {
                  this.cacheTelemetry(payload.device_id, payload.data, payload.timestamp);
                  this.onTelemetryDataListeners.forEach(listener => {
                    listener(payload.device_id!, payloadStr);
                  });
                  this.resetOfflineTimer();
                }
              } catch (e) {
                console.error('[MQTT] Parse error', e);
                if (onStatusChange) {
                  onStatusChange('connected', `Msg arrived but parse fail: ${e}.`);
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
      if (onStatusChange) {
        onStatusChange('disconnected', `Catch error: ${e.message || e}`);
      }
    }
  }

  public publishCommand(deviceId: string, targetDevice: string, action: string, param?: Record<string, number>) {
    let ctrlAction = new ControlAction();
    ctrlAction.target_device = targetDevice;
    ctrlAction.command = action;
    ctrlAction.parameters = param || { "duration_seconds": 15 };

    let ctrlMsg = new ControlMessage();
    ctrlMsg.cmd_id = "app_" + new Date().getTime();
    ctrlMsg.timestamp = new Date().getTime();
    ctrlMsg.msg_type = "control";
    ctrlMsg.action = ctrlAction;

    let payloadStr = JSON.stringify(ctrlMsg);

    if (!this.client || !this.connected) {
      console.warn(`[MQTT] Cannot publish to ${deviceId}, not connected.`);
      return;
    }

    let topic = `/wangnong_2026/device/${deviceId}/command`;
    console.info(`[MQTT] Publish to ${topic}: ${payloadStr}`);
    if (this.client.publish) {
      let pubOpts: MqttPublishOptions = {
        topic: topic,
        payload: payloadStr,
        qos: 1,
        retained: false
      };
      this.client.publish(pubOpts, (err, res) => {
        if (err) {
          console.error('[MQTT] Publish error', err);
        }
      });
    }
  }

  public disconnect() {
    this.connected = false;
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
