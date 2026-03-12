import { MockDataService } from '../mock/MockDataService';
import { SensorData } from '../models/SensorData';
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

class EnvironmentData {
  temperature?: number;
  humidity?: number;
  light?: number;
  co2?: number;
}

class EquipmentData {
  water_pump?: boolean;
  led_light?: boolean;
  led_brightness?: number;
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
  private onTelemetryData: ((deviceId: string, msgStr: string) => void) | null = null;
  private connected: boolean = false;
  private client: MqttClient | null = null;
  private mockDevices: string[] = ['A03_Node_01', 'A03_Node_02'];
  private deviceStates: Record<string, EquipmentData> = {
    'A03_Node_01': {
      water_pump: false,
      led_light: false,
      led_brightness: 50,
      fan: false,
      camera: false
    },
    'A03_Node_02': {
      water_pump: false,
      led_light: false,
      led_brightness: 50,
      fan: false,
      camera: false
    }
  };
  // Keep last known environment to avoid 0s when updating only equipment status
  private envStates: Record<string, EnvironmentData> = {
    'A03_Node_01': {
      temperature: 25,
      humidity: 60,
      light: 5000,
      co2: 400
    },
    'A03_Node_02': {
      temperature: 26.5,
      humidity: 55,
      light: 5000,
      co2: 400
    }
  };

  private constructor() {
  }

  public static getInstance(): MqttClientService {
    if (!MqttClientService.instance) {
      MqttClientService.instance = new MqttClientService();
    }
    return MqttClientService.instance;
  }

  public connect(brokerUrl: string, clientId: string,
    onTelemetryData: (deviceId: string, msgStr: string) => void,
    onStatusChange?: (status: 'connected' | 'mock' | 'disconnected', debugInfo?: string) => void) {
    this.onTelemetryData = onTelemetryData;
    console.info(`[MQTT-Mock] Connecting to ${brokerUrl}`);
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
            this.startMocking();
            if (onStatusChange) {
              onStatusChange('mock', `Connect failed: ${JSON.stringify(err)}`);
            }
            return;
          }

          console.info(`[MQTT] Connected to ${brokerUrl}`);
          this.connected = true;
          if (onStatusChange) {
            onStatusChange('connected', `Success connected to ${brokerUrl}`);
          }

          if (this.client) {
            let subOpts: MqttSubscribeOptions = { topic: '/wangnong_2026/device/+/telemetry', qos: 1 };

            this.client.messageArrived((err, mqttMessage: MqttMessage) => {
              if (err) {
                return;
              }
              let payloadStr = mqttMessage.payload;
              try {
                const payload = JSON.parse(payloadStr) as Record<string, string>;
                if (payload['device_id']) {
                  this.onTelemetryData?.(payload['device_id'], payloadStr);
                }
              } catch (e) {
                console.error('[MQTT] Parse error', e);
                if (onStatusChange) {
                  onStatusChange('connected', `Msg arrived but parse fail: ${e}.`);
                }
              }
            });

            this.client.subscribe(subOpts, (err, res) => {
              if (err) {
                console.error('[MQTT] Subscribe error', err);
              } else {
                console.info('[MQTT] Subscribed');
              }
            });
          }
        });
      }
    } catch (e) {
      console.error(`[MQTT] Library load failed, fallback to mock: ${e}`);
      this.startMocking();
      if (onStatusChange) {
        onStatusChange('mock', `Catch error: ${e.message || e}`);
      }
    }
  }

  private startMocking() {
    this.connected = true;
    MockDataService.getInstance().startMock((data: SensorData) => {
      if (!this.connected) {
        return;
      }

      this.mockDevices.forEach(deviceId => {
        let envData: EnvironmentData = {
          temperature: data.temperature + (deviceId === 'A03_Node_02' ? 1.5 : 0),
          humidity: data.humidity + (deviceId === 'A03_Node_02' ? -5 : 0),
          light: data.light,
          co2: data.co2
        };
        this.envStates[deviceId] = envData;

        let equipData: EquipmentData = this.deviceStates[deviceId];

        let tData: TelemetryData = {
          environment: envData,
          equipment: equipData
        };

        let payload: TelemetryPayload = {
          msg_type: "telemetry",
          device_id: deviceId,
          timestamp: new Date().getTime(),
          data: tData
        };

        if (this.onTelemetryData) {
          this.onTelemetryData(deviceId, JSON.stringify(payload));
        }
      });
    });
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

    if (this.client) {
      if (this.connected) {
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
      } else {
        if (!this.connected) {
          console.warn(`[MQTT-Mock] Cannot publish to ${deviceId}, not connected.`);
          return;
        }
        let topic = `command/${deviceId}`;
        console.info(`[MQTT-Mock] Publish to ${topic}: ${payloadStr}`);
      }
    } else {
      if (!this.connected) {
        console.warn(`[MQTT-Mock] Cannot publish to ${deviceId}, not connected.`);
        return;
      }
      let topic = `command/${deviceId}`;
      console.info(`[MQTT-Mock] Publish to ${topic}: ${payloadStr}`);
    }

    // Simulate command effect locally
    if (!this.deviceStates[deviceId]) {
      this.deviceStates[deviceId] = {
        water_pump: false,
        led_light: false,
        led_brightness: 50,
        fan: false,
        camera: false
      };
    }
    let mockState = this.deviceStates[deviceId];
    let isOn = action === 'turn_on';
    if (targetDevice === 'water_pump') {
      mockState.water_pump = isOn;
    }
    if (targetDevice === 'led_light') {
      mockState.led_light = isOn;
    }
    if (targetDevice === 'fan') {
      mockState.fan = isOn;
    }
    if (targetDevice === 'camera') {
      mockState.camera = isOn;
    }

    // Immediately trigger an update
    let envData = this.envStates[deviceId] || new EnvironmentData();
    let statePayload: TelemetryPayload = {
      msg_type: "telemetry",
      device_id: deviceId,
      timestamp: new Date().getTime(),
      data: {
        environment: envData,
        equipment: {
          water_pump: mockState.water_pump,
          led_light: mockState.led_light,
          led_brightness: mockState.led_brightness,
          fan: mockState.fan,
          camera: mockState.camera
        } as EquipmentData
      } as TelemetryData
    };
    if (this.onTelemetryData) {
      this.onTelemetryData(deviceId, JSON.stringify(statePayload));
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
    MockDataService.getInstance().stopMock();
    console.info('[MQTT] Disconnected');
  }
}
